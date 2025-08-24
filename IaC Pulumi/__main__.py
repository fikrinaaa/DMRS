import pulumi
import pulumi_kubernetes as k8s
from pulumi_kubernetes.helm.v3 import Chart, LocalChartOpts
import pulumi_digitalocean as do
import base64, json
from pulumi import ResourceOptions, Output, Config


registry_name  = "dmrs-1"
registry_user  = "kamiatunsp@gmail.com"
registry_token = "dop_v1_f0fc48e3ac4885947f240d8eb19648230dfd46b8901487957598fdac5eb5d04b"

auth_b64 = Output.secret(f"{registry_user}:{registry_token}").apply(
    lambda s: base64.b64encode(s.encode()).decode()
)
dockerconfigjson = Output.all(auth_b64, registry_name).apply(
    lambda args: json.dumps({
        "auths": { f"registry.digitalocean.com/{args[1]}": {"auth": args[0]} }
    })
)

dmrs_project = do.Project(
    "dmrs-project",
    name="DMRS",
    purpose="DMRS",
    environment="Development",
    description="Project untuk cluster DMRS",
)

cluster = do.KubernetesCluster(
    "dmrs-cluster",
    name="dmrs",
    region="sfo2",
    version="1.33.1-do.3",
    node_pool=do.KubernetesClusterNodePoolArgs(
        name="dmrs-1",
        size="s-4vcpu-8gb",
        node_count=2,
    ),
)

node_pool2 = do.KubernetesNodePool(
    "dmrs-pool-1",
    cluster_id=cluster.id,
    name="dmrs",
    size="s-2vcpu-4gb",
    node_count=1,
)

attach = do.ProjectResources(
    "dmrs-project-attach",
    project=dmrs_project.id,
    resources=[cluster.cluster_urn],
)

k8s_provider = k8s.Provider(
    "do-k8s",
    kubeconfig=cluster.kube_configs[0].raw_config,  
    enable_server_side_apply=True,
)

base_opts = pulumi.ResourceOptions(provider=k8s_provider, depends_on=[cluster])

ns = k8s.core.v1.Namespace(
    "dmrs-ns",
    metadata={"name": "dmrs"},
    opts=base_opts,
)

do_registry_secret = k8s.core.v1.Secret(
    "do-registry",
    metadata={"name": "do-registry", "namespace": "dmrs"},
    type="kubernetes.io/dockerconfigjson",
    string_data={".dockerconfigjson": dockerconfigjson},
    opts=ResourceOptions(provider=k8s_provider, depends_on=[cluster]),
) 


wazuh = k8s.kustomize.Directory(
    "wazuh",
    directory="wazuh-kubernetes/envs/local-env/",
    opts=pulumi.ResourceOptions.merge(base_opts, pulumi.ResourceOptions(depends_on=[ns])),
)

thehive = k8s.yaml.ConfigFile(
    "thehive-yaml",
    file="TheHive.yaml",
    opts=pulumi.ResourceOptions.merge(base_opts, pulumi.ResourceOptions(depends_on=[wazuh])),
)


shuffle = Chart(
    "shuffle",
    LocalChartOpts(
        path="./shuffle-chart",
        namespace="dmrs",
        values={"fullnameOverride": "shuffle"},
        transformations=[
            lambda obj: (
                obj.get("kind") == "Service"
                and obj["metadata"]["name"] == "shuffle-frontend"
                and obj["spec"].update({
                    "type": "NodePort",
                    "ports": [
                        {"name": "http", "port": 80, "targetPort": 80, "nodePort": 30080},
                        {"name": "https", "port": 443, "targetPort": 443, "nodePort": 30443},
                    ]
                })
            )
        ],
    ),
    opts=pulumi.ResourceOptions.merge(base_opts, pulumi.ResourceOptions(depends_on=[thehive])),
)

cortex = k8s.yaml.ConfigFile(
    "cortex-yaml",
    file="Cortex.yaml",
    opts=pulumi.ResourceOptions.merge(base_opts, pulumi.ResourceOptions(depends_on=[shuffle])),
)

configmap = k8s.yaml.ConfigFile(
    "configmap",
    file="configmap.yaml",
    opts=ResourceOptions(provider=k8s_provider, depends_on=[wazuh]),
)



pulumi.export("kubeconfig", cluster.kube_configs[0].raw_config)  
pulumi.export("wazuh_resource_count", wazuh.resources.apply(lambda r: len(r)))
pulumi.export("thehive_status", thehive.urn)
pulumi.export("cortex_status", cortex.urn)
pulumi.export("shuffle_status", shuffle.urn)





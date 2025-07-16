"""A Kubernetes Python Pulumi program"""
import pulumi
import pulumi_kubernetes as k8s
from pulumi_kubernetes.helm.v3 import Chart, LocalChartOpts


# Deploy Wazuh Kubernetes
wazuh = k8s.kustomize.Directory(
    "wazuh",
    directory="wazuh-kubernetes/envs/local-env/"
)

# Deploy TheHive.yaml
thehive = k8s.yaml.ConfigFile(
    "thehive-yaml",
    file="TheHive.yaml"
)

# Deploy Cortex.yaml
cortex = k8s.yaml.ConfigFile(
    "cortex-yaml",
    file="Cortex.yaml"
)

# Deploy Shuffle Charts
shuffle = Chart(
    "shuffle",
    LocalChartOpts(
        path="./shuffle-chart",  
        namespace="dmrs",
        values={
            "fullnameOverride": "shuffle",
        },
        transformations=[
            lambda obj: (
                obj.get("kind") == "Service"
                and obj["metadata"]["name"] == "shuffle-frontend"
                and obj["spec"].update({
                    "type": "NodePort",
                    "ports": [
                        {
                            "name": "http",
                            "port": 80,
                            "targetPort": 80,
                            "nodePort": 30080
                        },
                        {
                            "name": "https",
                            "port": 443,
                            "targetPort": 443,
                            "nodePort": 30443
                        }
                    ]
                })
            )
        ]
    )
)

# Output untuk validasi
pulumi.export("wazuh_resource_count", wazuh.resources.apply(lambda r: len(r)))
pulumi.export("thehive_status", thehive.urn)
pulumi.export("cortex_status", cortex.urn)
pulumi.export("shuffle_status", shuffle.urn)

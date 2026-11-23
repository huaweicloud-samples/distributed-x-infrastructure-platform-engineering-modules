# =============================================================================
# backend-node-svc
# 模块能力：CCE 命名空间 + 后端 Service 工作负载（调度到节点池）
# 资源构成：
#   - CCE 命名空间（huaweicloud_cce_namespace）
#   - K8s Deployment / Service YAML 模板（由 kubectl apply 部署）
# 实现说明：
#   - 网络模型统一走 CNI（CCE 强制），不使用 bridge 模式
#   - 节点形态调度通过 nodeSelector 实现（参见 cce-node-pool-env）
#   - 自动扩缩由 K8s HPA 承担
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

provider "huaweicloud" { region = var.region }

variable "region" {
  type    = string
  default = "cn-north-4"
}
variable "project_name" {
  type    = string
  default = "backend-node-svc"
}
variable "cluster_id" { type = string }
variable "image_url" { type = string }
variable "container_port" {
  type    = number
  default = 8080
}
variable "replicas" {
  type    = number
  default = 2
}
variable "node_pool_label" {
  type    = string
  default = "workload=node"
}
variable "ping_topic_urn" {
  type    = string
  default = ""
}

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

output "namespace_id" {
  value = huaweicloud_cce_namespace.this.id
}

output "deployment_yaml_hint" {
  value = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${var.project_name}
      namespace: ${huaweicloud_cce_namespace.this.name}
    spec:
      replicas: ${var.replicas}
      selector: { matchLabels: { app: ${var.project_name} } }
      template:
        metadata: { labels: { app: ${var.project_name} } }
        spec:
          nodeSelector:
            ${var.node_pool_label}: "true"
          containers:
            - name: app
              image: ${var.image_url}
              ports: [ { containerPort: ${var.container_port} } ]
              env: [ { name: PING_TOPIC_URN, value: "${var.ping_topic_urn}" } ]
    ---
    apiVersion: v1
    kind: Service
    metadata: { name: ${var.project_name}, namespace: ${huaweicloud_cce_namespace.this.name} }
    spec:
      clusterIP: None
      selector: { app: ${var.project_name} }
      ports: [ { port: ${var.container_port}, targetPort: ${var.container_port} } ]
  YAML
}

# =============================================================================
# backend-serverless-svc
# 模块能力：CCE 命名空间 + 后端 Service 工作负载（无节点选择约束）
# 资源构成：CCE 命名空间 + K8s Deployment / Service YAML 模板
# 实现说明：
#   - 容器组网络使用 IP 类型 Service 与 CNI 网络模型
#   - 服务发现使用 K8s Headless Service
#   - 自动扩缩由 K8s HPA（CPU / 内存利用率）承担
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

provider "huaweicloud" {
  region = var.region
}

variable "region" {
  type    = string
  default = "cn-north-4"
}

variable "project_name" {
  type    = string
  default = "backend-serverless-svc"
}

variable "cluster_id" {
  type = string
}

variable "image_url" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "replicas" {
  type    = number
  default = 2
}

variable "cpu" {
  type    = number
  default = 500
}

variable "memory" {
  type    = number
  default = 1024
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
      selector:
        matchLabels: { app: ${var.project_name} }
      template:
        metadata:
          labels: { app: ${var.project_name} }
        spec:
          containers:
            - name: app
              image: ${var.image_url}
              ports: [ { containerPort: ${var.container_port} } ]
              resources:
                requests: { cpu: "${var.cpu}m", memory: "${var.memory}Mi" }
              env:
                - name: PING_TOPIC_URN
                  value: "${var.ping_topic_urn}"
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ${var.project_name}
      namespace: ${huaweicloud_cce_namespace.this.name}
    spec:
      clusterIP: None
      selector: { app: ${var.project_name} }
      ports: [ { port: ${var.container_port}, targetPort: ${var.container_port} } ]
    ---
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: ${var.project_name}
      namespace: ${huaweicloud_cce_namespace.this.name}
    spec:
      scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: ${var.project_name}
      minReplicas: 1
      maxReplicas: 10
      metrics:
        - type: Resource
          resource:
            name: cpu
            target: { type: Utilization, averageUtilization: 50 }
        - type: Resource
          resource:
            name: memory
            target: { type: Utilization, averageUtilization: 50 }
  YAML
}

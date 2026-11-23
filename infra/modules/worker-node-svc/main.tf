# =============================================================================
# worker-node-svc
# 模块能力：DMS Kafka 队列 + CCE 消费者 Deployment（节点池调度）
# 资源构成：DMS Kafka 实例 / Topic + CCE Deployment YAML 模板
# 实现说明：
#   - 死信队列用独立 Kafka Topic 承载，配合监控告警实现可观测
#   - 网络模型统一走 CNI
#   - 按队列积压伸缩由消费者自管理或 K8s 外部指标 HPA 承担
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    huaweicloud = { source = "huaweicloud/huaweicloud", version = "~> 1.70" }
  }
}

provider "huaweicloud" { region = var.region }

variable "region" {
  type    = string
  default = "cn-north-4"
}
variable "project_name" {
  type    = string
  default = "worker-node-svc"
}
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "security_group_id" { type = string }
variable "cluster_id" { type = string }
variable "image_url" { type = string }
variable "replicas" {
  type    = number
  default = 2
}
variable "kafka_flavor_id" {
  type    = string
  default = "c6.2u4g.cluster"
}
variable "kafka_broker_num" {
  type    = number
  default = 3
}
variable "kafka_storage_size" {
  type    = number
  default = 300
}
variable "node_pool_label" {
  type    = string
  default = "workload=node"
}

resource "huaweicloud_dms_kafka_instance" "this" {
  name              = "${var.project_name}-kafka"
  engine_version    = "2.7"
  storage_spec_code = "dms.physical.storage.high"
  flavor_id         = var.kafka_flavor_id
  broker_num        = var.kafka_broker_num
  storage_space     = var.kafka_storage_size
  vpc_id            = var.vpc_id
  network_id        = var.subnet_id
  security_group_id = var.security_group_id
  available_zones   = ["${var.region}a", "${var.region}b", "${var.region}c"]
}

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

output "kafka_brokers" { value = huaweicloud_dms_kafka_instance.this.connect_address }
output "namespace_id" { value = huaweicloud_cce_namespace.this.id }
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
          nodeSelector: { ${var.node_pool_label}: "true" }
          containers:
            - name: worker
              image: ${var.image_url}
              env:
                - name: KAFKA_BROKERS
                  value: "${huaweicloud_dms_kafka_instance.this.connect_address}"
                - name: TOPIC
                  value: "${var.project_name}-processing"
                - name: DLQ_TOPIC
                  value: "${var.project_name}-dlq"
  YAML
}

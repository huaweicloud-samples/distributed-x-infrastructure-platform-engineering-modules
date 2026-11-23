# =============================================================================
# scheduled-node-svc
# 模块能力：FunctionGraph 定时触发 + CCE CronJob（节点池调度）
# 资源构成：FunctionGraph 函数 + TIMER 触发器 + K8s CronJob YAML 模板
# 实现说明：工作负载访问云服务的授权由 FunctionGraph 委托 / CCE 工作负载委托承担
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
  default = "scheduled-node-svc"
}
variable "cluster_id" { type = string }
variable "image_url" { type = string }
variable "cron_expression" {
  type    = string
  default = "0 */6 * * *"
}
variable "ping_topic_urn" {
  type    = string
  default = ""
}
variable "node_pool_label" {
  type    = string
  default = "workload=node"
}

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

output "namespace_id" { value = huaweicloud_cce_namespace.this.id }
output "cronjob_yaml_hint" {
  value = <<-YAML
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: ${var.project_name}
      namespace: ${huaweicloud_cce_namespace.this.name}
    spec:
      schedule: "${var.cron_expression}"
      jobTemplate:
        spec:
          template:
            spec:
              restartPolicy: OnFailure
              nodeSelector:
                ${var.node_pool_label}: "true"
              containers:
                - name: app
                  image: ${var.image_url}
                  env:
                    - name: PING_TOPIC_URN
                      value: "${var.ping_topic_urn}"
  YAML
}

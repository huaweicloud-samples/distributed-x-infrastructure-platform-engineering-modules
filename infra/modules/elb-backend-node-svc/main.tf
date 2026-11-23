# =============================================================================
# elb-backend-node-svc
# 模块能力：独享型 ELB（应用型）+ CCE 工作负载（节点池调度）
# 资源构成：ELB 实例 / 监听器 / 后端组 / 健康检查 + CCE Deployment / Service YAML 模板
# 实现说明：
#   - 后端组使用 IP 类型后端，与 CNI 网络模型一致
#   - 节点形态调度通过 nodeSelector 实现
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
  default = "elb-backend-node-svc"
}
variable "vpc_id" { type = string }
variable "cluster_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
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

resource "huaweicloud_networking_secgroup" "elb" {
  name = "${var.project_name}-elb-sg"
}

resource "huaweicloud_networking_secgroup_rule" "elb_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.elb.id
}

resource "huaweicloud_elb_loadbalancer" "this" {
  name              = "${var.project_name}-elb"
  loadbalancer_type = "application"
  vpc_id            = var.vpc_id
  iptype            = "5_public"
  availability_zone = [for s in var.public_subnet_ids : "${var.region}a"]
}

resource "huaweicloud_elb_pool" "this" {
  name            = "${var.project_name}-pool"
  protocol        = "HTTP"
  lb_method       = "round_robin"
  loadbalancer_id = huaweicloud_elb_loadbalancer.this.id
  vpc_id          = var.vpc_id
  type            = "ip"
}

resource "huaweicloud_elb_monitor" "this" {
  pool_id     = huaweicloud_elb_pool.this.id
  protocol    = "HTTP"
  url_path    = "/health"
  port        = var.container_port
  interval    = 30
  timeout     = 10
  max_retries = 3
}

resource "huaweicloud_elb_listener" "this" {
  name            = "${var.project_name}-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = huaweicloud_elb_loadbalancer.this.id
  default_pool_id = huaweicloud_elb_pool.this.id
}

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

output "elb_ip" { value = huaweicloud_elb_loadbalancer.this.ipv4_eip }
output "elb_id" { value = huaweicloud_elb_loadbalancer.this.id }
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
          nodeSelector:
            ${var.node_pool_label}: "true"
          containers:
            - name: app
              image: ${var.image_url}
              ports: [ { containerPort: ${var.container_port} } ]
    ---
    apiVersion: v1
    kind: Service
    metadata: { name: ${var.project_name}, namespace: ${huaweicloud_cce_namespace.this.name} }
    spec:
      type: ClusterIP
      selector: { app: ${var.project_name} }
      ports: [ { port: ${var.container_port}, targetPort: ${var.container_port} } ]
  YAML
}

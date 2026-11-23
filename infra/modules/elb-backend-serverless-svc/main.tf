# =============================================================================
# elb-backend-serverless-svc
# 模块能力：独享型 ELB（应用型）+ CCE 工作负载模板
# 资源构成：ELB 实例 / 监听器 / 后端组 / 健康检查 + K8s Deployment / Service / HPA YAML 模板
# 实现说明：
#   - 容器工作负载由 kubectl apply 部署，Terraform 只落网络与负载均衡
#   - 服务发现使用 K8s Service（ClusterIP / Headless）
#   - 自动扩缩由 CCE HPA 承担
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

# -----------------------------------------------------------------------------
# 变量
# -----------------------------------------------------------------------------

variable "region" {
  type    = string
  default = "cn-north-4"
}

variable "project_name" {
  type    = string
  default = "elb-backend-serverless-svc"
}

variable "vpc_id" {
  type = string
}

variable "cluster_id" {
  type        = string
  description = "CCE 集群 ID（来自 cce-cluster-env）"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "用于 ELB 的公网子网 ID 列表"
}

variable "service_subnet_ids" {
  type        = list(string)
  description = "用于 Service / Pod 的子网 ID 列表（私网）"
}

variable "loadbalancer_flavor" {
  type    = string
  default = "L7_flavor.elb.s1.medium"
}

variable "image_url" {
  type        = string
  description = "容器镜像（SWR 地址）"
}

variable "container_port" {
  type    = number
  default = 80
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

# -----------------------------------------------------------------------------
# ELB 独享型实例
# -----------------------------------------------------------------------------

resource "huaweicloud_elb_loadbalancer" "this" {
  name              = "${var.project_name}-elb"
  loadbalancer_type = "application"
  vpc_id            = var.vpc_id
  availability_zone = [for s in var.public_subnet_ids : "${var.region}a"]

  iptype            = "5_public"
  protection_status = "nonProtection"
  protection_reason = null

  tags = {
    project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# ELB 监听器（80 → 后端 Pool）
# -----------------------------------------------------------------------------

resource "huaweicloud_elb_listener" "this" {
  name            = "${var.project_name}-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = huaweicloud_elb_loadbalancer.this.id
  default_pool_id = huaweicloud_elb_pool.this.id
  description     = "Public HTTP listener for ${var.project_name}"

  tags = {
    project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# ELB 后端服务器组（IP 类型后端）
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# 安全组（ELB 入口 + Pod 出站）
# -----------------------------------------------------------------------------

resource "huaweicloud_networking_secgroup" "elb" {
  name        = "${var.project_name}-elb-sg"
  description = "ELB ingress for ${var.project_name}"
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

resource "huaweicloud_networking_secgroup_rule" "elb_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.elb.id
  # protocol 省略 = 全协议放行
}

# -----------------------------------------------------------------------------
# CCE Namespace
# -----------------------------------------------------------------------------

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

# -----------------------------------------------------------------------------
# 输出（不含 Deployment / HPA → 这些通过 kubectl 单独管理，符合 K8s 生态惯例）
# -----------------------------------------------------------------------------

output "elb_id" {
  value = huaweicloud_elb_loadbalancer.this.id
}

output "elb_ip" {
  value = huaweicloud_elb_loadbalancer.this.ipv4_address
}

output "elb_eip" {
  value = huaweicloud_elb_loadbalancer.this.ipv4_eip
}

output "elb_pool_id" {
  value = huaweicloud_elb_pool.this.id
}

output "elb_listener_id" {
  value = huaweicloud_elb_listener.this.id
}

output "namespace_id" {
  value = huaweicloud_cce_namespace.this.id
}

output "deployment_yaml_hint" {
  value = <<-YAML
    # 由 kubectl apply 部署（不在 Terraform 中管理）
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${var.project_name}
      namespace: ${huaweicloud_cce_namespace.this.name}
    spec:
      replicas: ${var.replicas}
      selector:
        matchLabels:
          app: ${var.project_name}
      template:
        metadata:
          labels:
            app: ${var.project_name}
        spec:
          containers:
            - name: app
              image: ${var.image_url}
              ports:
                - containerPort: ${var.container_port}
              resources:
                requests:
                  cpu: "${var.cpu}m"
                  memory: "${var.memory}Mi"
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
      type: ClusterIP
      selector:
        app: ${var.project_name}
      ports:
        - port: ${var.container_port}
          targetPort: ${var.container_port}
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
            target:
              type: Utilization
              averageUtilization: 50
  YAML
}

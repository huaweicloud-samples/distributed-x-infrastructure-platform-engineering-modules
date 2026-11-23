# =============================================================================
# obs-bucket-component
# 模块能力：OBS 桶（最小可复用组件）
# 资源构成：OBS 桶（私有 ACL）
# 实现说明：桶名使用 bucket_name_prefix 拼接的全局唯一前缀，apply 时按需调整
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

variable "bucket_name_prefix" {
  type        = string
  default     = "component-bucket-"
  description = "OBS 桶名前缀（全局唯一，仅在 bucket_name 为空时拼接时间戳生成一次性唯一名）"
}

# 显式桶名：非空时直接使用，保证 apply 可重复、桶名稳定（不再随 timestamp() 反复重建）。
# 为空时回退到「前缀+时间戳」以兼容全新部署的一次性唯一命名。
variable "bucket_name" {
  type        = string
  default     = ""
  description = "显式 OBS 桶名；优先于 bucket_name_prefix，用于复用已存在桶、避免反复销毁重建"
}

variable "versioning" {
  type    = bool
  default = true
}

# -----------------------------------------------------------------------------
# OBS 桶
# -----------------------------------------------------------------------------

resource "huaweicloud_obs_bucket" "this" {
  bucket        = var.bucket_name != "" ? var.bucket_name : "${var.bucket_name_prefix}${formatdate("YYYYMMDDhhmmss", timestamp())}"
  acl           = "private"
  force_destroy = true
  versioning    = var.versioning

  tags = {
    source = "obs-bucket-component"
  }
}

# -----------------------------------------------------------------------------
# 输出
# -----------------------------------------------------------------------------

output "bucket_name" {
  value = huaweicloud_obs_bucket.this.bucket
}

output "bucket_domain_name" {
  value = huaweicloud_obs_bucket.this.bucket_domain_name
}

output "bucket_arn" {
  value = format("obs:::%s", huaweicloud_obs_bucket.this.id)
}

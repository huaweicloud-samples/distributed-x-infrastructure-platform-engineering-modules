# obs-bucket-component 模块

OBS 桶（最小可复用组件）。

## 用途

为其他模块或业务提供对象存储桶，支持按需开启版本控制。

## 使用方式

```hcl
module "bucket" {
  source = "../obs-bucket-component"

  bucket_name_prefix = "demo-bucket-"
  versioning         = true
}

output "bucket" { value = module.bucket.bucket_name }
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_obs_bucket.this` | OBS 桶（私有读写，可按需开启版本控制） |

## 关键输出

| 输出 | 说明 |
|---|---|
| `bucket_name` | 桶名 |
| `bucket_domain_name` | 桶访问域名 |
| `bucket_arn` | 桶资源标识 |

## 实现说明

桶名使用 bucket_name_prefix 拼接的全局唯一前缀，apply 时按需调整。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

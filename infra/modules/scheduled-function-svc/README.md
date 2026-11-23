# scheduled-function-svc 模块

FunctionGraph 定时任务（VPC 内运行）。

## 用途

周期性任务且需访问 VPC 内资源（数据库 / 缓存 / 内网服务）；函数在指定 VPC 与子网内运行。

## 使用方式

```hcl
module "scheduled" {
  source = "../scheduled-function-svc"

  project_name      = "demo"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = [module.vpc.private_subnet_one_id]
  security_group_id = module.vpc.vpc_default_security_group_id
  function_code_url = "https://your-bucket.obs.cn-north-4.myhuaweicloud.com/job.zip"
  cron_expression   = "0 0 2 * * ?"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_fgs_function.this` | FunctionGraph 函数（含 VPC 网络配置） |
| `huaweicloud_fgs_trigger.schedule` | TIMER 触发器 |
| `huaweicloud_identity_agency.fgs` | 函数委托 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `function_urn` | 函数 URN |
| `trigger_id` | 触发器 ID |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

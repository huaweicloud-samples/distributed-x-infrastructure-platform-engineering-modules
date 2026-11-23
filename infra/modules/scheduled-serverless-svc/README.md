# scheduled-serverless-svc 模块

FunctionGraph 定时触发器（无容器依赖的定时任务）。

## 用途

轻量周期任务，任务体即函数本身，不需要容器运行时；定时表达式直接配在 TIMER 触发器上。

## 使用方式

```hcl
module "scheduled" {
  source = "../scheduled-serverless-svc"

  project_name      = "demo"
  function_code_url = "https://your-bucket.obs.cn-north-4.myhuaweicloud.com/job.zip"
  function_handler  = "index.handler"
  function_runtime  = "Python3.10"
  cron_expression   = "0 0 2 * * ?"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_fgs_function.this` | FunctionGraph 函数 |
| `huaweicloud_fgs_trigger.schedule` | TIMER 触发器 |
| `huaweicloud_identity_agency.fgs` | 函数委托 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `function_urn` | 函数 URN |
| `trigger_id` | 触发器 ID |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

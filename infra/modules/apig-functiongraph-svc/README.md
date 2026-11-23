# apig-functiongraph-svc 模块

APIG 专享版（API 网关）+ FunctionGraph（函数计算）对外提供 HTTP API。

## 用途

对外暴露 HTTP API，后端走 FunctionGraph 函数；适合轻量 API 服务（CRUD / Webhook / 异步触发等）。

## 使用方式

```hcl
module "api" {
  source = "../apig-functiongraph-svc"

  project_name      = "demo"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_one_id
  security_group_id = module.vpc.vpc_default_security_group_id
  function_code_url = "https://your-bucket.obs.cn-north-4.myhuaweicloud.com/function.zip"
  ping_topic_urn    = module.vpc.ping_topic_urn
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_apig_instance.this / apig_group.this / apig_api.this` | APIG 专享版实例 / 分组 / API |
| `huaweicloud_apig_environment.this / apig_api_publishment.this` | API 发布环境 / 发布动作 |
| `huaweicloud_fgs_function.this` | FunctionGraph 函数 |
| `huaweicloud_lts_group.this / lts_stream.this` | LTS 日志组 / 日志流 |
| `huaweicloud_identity_agency.fgs` | 函数委托 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `apig_api_url` | APIG 实例入口地址（调用地址的主机部分） |
| `apig_group_id` | API 所属分组 ID |
| `apig_environment_name` | API 已发布到的环境名称 |
| `function_urn` | 函数 URN |
| `lts_stream_id` | 日志流 ID |

## 实现说明

- **API 必须发布后才可调用**：仅创建 API 定义不会产生对外入口，本模块通过 `huaweicloud_apig_environment` + `huaweicloud_apig_api_publishment` 将 API 发布到 `environment_name`（默认 `RELEASE`）指定的环境。
- **环境重名**：若目标实例已存在同名环境，`apig_environment` 会创建失败；此时把 `environment_name` 改为实例中已有环境名，并改为用 `data` 引用该环境。
- **完整调用地址**：由「实例入口地址 + 分组 ID + 环境名 + API 请求路径」构成，具体地址以 APIG 控制台该 API 的调用地址为准。
- **函数代码来源**：函数以 `code_type = "obs"` 从 OBS 对象取码，`function_code_url` 需指向同区域的 zip 对象。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

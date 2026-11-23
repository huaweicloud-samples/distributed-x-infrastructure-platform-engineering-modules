# functiongraph-vpc 模块

单 VPC + 单 FunctionGraph 函数（函数在 VPC 内运行）。

## 用途

最小的「函数 + 私有网络」组合，适合需要访问 VPC 内资源（数据库 / 缓存 / 内网服务）的函数场景。

## 使用方式

```hcl
module "fn_vpc" {
  source = "../functiongraph-vpc"

  project_name      = "demo"
  function_code_url = "https://your-bucket.obs.cn-north-4.myhuaweicloud.com/function.zip"
  function_handler  = "index.handler"
  function_runtime  = "Python3.10"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_vpc.this` | VPC |
| `huaweicloud_vpc_subnet.public / private` | 公网 / 私网子网 |
| `huaweicloud_networking_secgroup.this` | 安全组 |
| `huaweicloud_networking_secgroup_rule.egress_all` | 出向规则 |
| `huaweicloud_identity_agency.fgs` | 函数委托（访问云服务的授权载体） |
| `huaweicloud_fgs_function.this` | FunctionGraph 函数（含 VPC 网络配置） |

## 关键输出

| 输出 | 说明 |
|---|---|
| `vpc_id / subnet_id / security_group_id` | 网络标识 |
| `function_urn` | 函数 URN |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

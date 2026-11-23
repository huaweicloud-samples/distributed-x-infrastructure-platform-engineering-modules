# vpc-env 模块

基础 VPC + 子网 + 消息通知主题。

## 用途

提供公私网子网划分与默认安全组，是其他模块的网络底座。

## 使用方式

```hcl
module "vpc" {
  source = "../vpc-env"

  project_name = "demo"
  region       = "cn-north-4"
  vpc_cidr     = "10.0.0.0/16"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_vpc.this` | VPC |
| `huaweicloud_vpc_subnet.public_one / public_two` | 公网子网 ×2 |
| `huaweicloud_vpc_subnet.private_one / private_two` | 私网子网 ×2 |
| `huaweicloud_networking_secgroup.default` | 默认安全组 |
| `huaweicloud_networking_secgroup_rule.allow_http_ingress / allow_all_egress` | 安全组规则 |
| `huaweicloud_smn_topic.ping` | 消息通知主题 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_default_security_group_id` | 默认安全组 ID |
| `public_subnet_one_id / public_subnet_two_id` | 公网子网 ID |
| `private_subnet_one_id / private_subnet_two_id` | 私网子网 ID |
| `ping_topic_urn / ping_topic_name` | 消息通知主题标识 |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

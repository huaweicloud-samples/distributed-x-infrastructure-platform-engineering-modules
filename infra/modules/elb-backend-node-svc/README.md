# elb-backend-node-svc 模块

独享型 ELB（应用型）+ CCE 工作负载（节点池调度）。

## 用途

对外提供七层负载均衡入口，后端为节点池调度的容器工作负载。

## 使用方式

```hcl
module "lb" {
  source = "../elb-backend-node-svc"

  project_name       = "demo"
  vpc_id             = module.vpc.vpc_id
  cluster_id         = module.node_env.cluster_id
  public_subnet_ids  = [module.vpc.public_subnet_one_id, module.vpc.public_subnet_two_id]
  image_url          = "swr.cn-north-4.myhuaweicloud.com/demo/app:latest"
  container_port     = 8080
  replicas           = 2
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_elb_loadbalancer.this` | 独享型 ELB 实例 |
| `huaweicloud_elb_listener.this` | 监听器 |
| `huaweicloud_elb_pool.this` | 后端组（IP 类型后端） |
| `huaweicloud_networking_secgroup.elb / rule.elb_http` | ELB 安全组与入向规则 |
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `elb_id / elb_ip` | ELB 实例 ID / 入口 IP |
| `elb_pool_id / elb_listener_id` | 后端组 / 监听器 ID |
| `namespace_id` | 命名空间 ID |
| `deployment_yaml_hint` | K8s Deployment / Service YAML 模板 |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。

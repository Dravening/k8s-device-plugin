# k8s-device-plugin解析

本文对k8s-device-plugin-v1.11版本的工作原理进行解析。

### 基本知识

在本小节中，会对一些基本概念进行说明

##### kubelet_internal_checkpoint

```
[root@master01 device-plugins]# pwd
/var/lib/kubelet/device-plugins
[root@XXX device-plugins]# ls
DEPRECATION  kubelet_internal_checkpoint  kubelet.sock
```

> **`kubelet_internal_checkpoint:`** 保存了`device manager`的状态, `device manager`重启的时候会从该文件中加载数据. **`kubelet.sock:`** `device manger`的服务端, 各种`device-plugin`向该服务端请求注册.

```
[root@cosmo-ai01 device-plugins]# cat kubelet_internal_checkpoint | jq
{
  "Data": {
    "PodDeviceEntries": [
      {
        "PodUID": "f320f827-2a71-486b-a551-28c650dbaf1e",
        "ContainerName": "ubuntu-container",
        "ResourceName": "nvidia.com/gpu",
        "DeviceIDs": {
          "0": [
            "GPU-709fac35-5f40-624b-90f7-b0a3db7a97a0-1"
          ]
        },
        "AllocResp": "CkIKFk5WSURJQV9WSVNJQkxFX0RFVklDRVMSKEdQVS03MDlmYWMzNS01ZjQwLTYyNGItOTBmNy1iMGEzZGI3YTk3YTAKGQoUQ1VEQV9ERVZJQ0VfU01fTElNSVQSATAKVwofQ1VEQV9ERVZJQ0VfTUVNT1JZX1NIQVJFRF9DQUNIRRI0L3RtcC92Z3B1LzMwYzYxNWVlLTI5OGYtNDhlZS04OGIyLTE2YWU1OWMxMDA5Yy5jYWNoZQoaChJDVURBX09WRVJTVUJTQ1JJQkUSBHRydWUKJAoaQ1VEQV9ERVZJQ0VfTUVNT1JZX0xJTUlUXzASBjE2MDAwbRI6ChovdXNyL2xvY2FsL3ZncHUvbGlidmdwdS5zbxIaL3Vzci9sb2NhbC92Z3B1L2xpYnZncHUuc28YARI1ChIvZXRjL2xkLnNvLnByZWxvYWQSHS91c3IvbG9jYWwvdmdwdS9sZC5zby5wcmVsb2FkGAESXQoJL3RtcC92Z3B1ElAvdXNyL2xvY2FsL3ZncHUvY29udGFpbmVycy9mMzIwZjgyNy0yYTcxLTQ4NmItYTU1MS0yOGM2NTBkYmFmMWVfdWJ1bnR1LWNvbnRhaW5lchIeCg0vdG1wL3ZncHVsb2NrEg0vdG1wL3ZncHVsb2Nr"
      },
      {
        "PodUID": "a2ab1d63-8519-4ff7-9501-edc58ae1d6a4",
        "ContainerName": "ubuntu-container",
        "ResourceName": "nvidia.com/gpu",
        "DeviceIDs": {
          "0": [
            "GPU-709fac35-5f40-624b-90f7-b0a3db7a97a0-2"
          ]
        },
        "AllocResp": "CiQKGkNVREFfREVWSUNFX01FTU9SWV9MSU1JVF8wEgYxNjAwMG0KQgoWTlZJRElBX1ZJU0lCTEVfREVWSUNFUxIoR1BVLWZjZGEwNTZmLTc3YzYtN2ZkZi1mN2M3LTY0NTM1MTFlYWFhMQoZChRDVURBX0RFVklDRV9TTV9MSU1JVBIBMApXCh9DVURBX0RFVklDRV9NRU1PUllfU0hBUkVEX0NBQ0hFEjQvdG1wL3ZncHUvYzQ1N2Q4ODItMmIxNi00YWQ5LWE5NjAtYTEzZTZjMDg0YTkyLmNhY2hlChoKEkNVREFfT1ZFUlNVQlNDUklCRRIEdHJ1ZRI6ChovdXNyL2xvY2FsL3ZncHUvbGlidmdwdS5zbxIaL3Vzci9sb2NhbC92Z3B1L2xpYnZncHUuc28YARI1ChIvZXRjL2xkLnNvLnByZWxvYWQSHS91c3IvbG9jYWwvdmdwdS9sZC5zby5wcmVsb2FkGAESXQoJL3RtcC92Z3B1ElAvdXNyL2xvY2FsL3ZncHUvY29udGFpbmVycy9hMmFiMWQ2My04NTE5LTRmZjctOTUwMS1lZGM1OGFlMWQ2YTRfdWJ1bnR1LWNvbnRhaW5lchIeCg0vdG1wL3ZncHVsb2NrEg0vdG1wL3ZncHVsb2Nr"
      }
    ],
    "RegisteredDevices": {
      "domain1.com/resource1": [
        "dev5",
        "dev1",
        "dev2",
        "dev3",
        "dev4"
      ],
      "domain2.com/resource2": [
        "dev1",
        "dev2"
      ]
    }
  },
  "Checksum": 216033768
}
```

这是一个`kubelet_internal_checkpoint`例子, 可以看到有两个比较重要的部分:

> **RegisteredDevices:** 当前向`kubelet`注册的资源以及这些资源所拥有的设备, 需要指出的是这些设备是`healthy`的才会出现在这里, `unhealthy`的设备不会持久到`kubelet_internal_checkpoint`中.
>
> **PodDeviceEntries:** 这个就是本文要涉及的内容, 可以看到`PodDeviceEntries`中有五个属性分别为`PodUID`, `ContainerName`, `ResourceName`以及`DeviceIDs`和`AllocResp`. 表明该`pod`(`f320f827-2a71-486b-a551-28c650dbaf1e`)中的容器(`ubuntu-container`)使用了资源(`nvidia.com/gpu`)的设备(`GPU-709fac35-5f40-624b-90f7-b0a3db7a97a0-1`和`GPU-709fac35-5f40-624b-90f7-b0a3db7a97a0-2`).
>
> **AllocResp:** 指的是一些`env`, `mount`信息，用于指定docker启动参数

`kubelet_internal_checkpoint`文件对应的数据结构如下：

```go
// pkg/kubelet/cm/devicemanager/checkpoint/checkpoint.go
type PodDevicesEntry struct {
    PodUID        string
    ContainerName string
    ResourceName  string
    DeviceIDs     []string
    AllocResp     []byte
}
type checkpointData struct {
    PodDeviceEntries  []PodDevicesEntry
    RegisteredDevices map[string][]string
}
type Data struct {
    Data     checkpointData
    Checksum checksum.Checksum
}
```

```go
// 对于该文件的操作
// pkg/kubelet/cm/devicemanager/checkpoint/checkpoint.go
type DeviceManagerCheckpoint interface {
    checkpointmanager.Checkpoint
    GetData() ([]PodDevicesEntry, map[string][]string)
}
func (cp *Data) MarshalCheckpoint() ([]byte, error) {
    cp.Checksum = checksum.New(cp.Data)
    return json.Marshal(*cp)
}
func (cp *Data) UnmarshalCheckpoint(blob []byte) error {
    return json.Unmarshal(blob, cp)
}
func (cp *Data) VerifyChecksum() error {
    return cp.Checksum.Verify(cp.Data)
}
func (cp *Data) GetData() ([]PodDevicesEntry, map[string][]string) {
    return cp.Data.PodDeviceEntries, cp.Data.RegisteredDevices
}
```

```go
// deviceAllocateInfo
type deviceAllocateInfo struct {
    // deviceIds contains device Ids allocated to this container for the given resourceName.
    deviceIds sets.String
    // allocResp contains cached rpc AllocateResponse.
    allocResp *pluginapi.ContainerAllocateResponse
}
type resourceAllocateInfo map[string]deviceAllocateInfo // Keyed by resourceName.
type containerDevices map[string]resourceAllocateInfo   // Keyed by containerName.
type podDevices map[string]containerDevices             // Keyed by podUID.
```

### 实战流程

本次对k8s-device-plugin-v1.11源码进行魔改，增加了mockDevices的功能，即在没有GPU的情况下让k8s认为存在gpu，以此来认识k8s提供的plugin-manager与我们的plugin应该如何交互。

详细代码略，请参考本项目commit。

##### 部署

```
# 使用如下命令进行编译（也可以略过这步，直接嫖我的镜像）
git pull
make build
```

```
# 使用如下命令进行部署，如果没有helm请自行安装。
helm install --name mock-device-plugin --namespace mock-device ./helm/mock-device-plugin.tgz
```

部署成功后，可以查看任意一个节点的信息

```
[root@k8s-master01 k8s-device-plugin]# kubectl describe node k8s-node01
Name:               k8s-node01
...
...
...
Addresses:
  InternalIP:  10.206.68.1
  Hostname:    k8s-node01
Capacity:
  cpu:                40
  mock/gpu:           10
  ephemeral-storage:  467028168Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             131661420Ki
  pods:               110
Allocatable:
  cpu:                40
  mock/gpu:           10
  ephemeral-storage:  478236844027
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             131661420Ki
  pods:               110
...
...
...
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                2362m (5%)   8610m (21%)
  memory             2873Mi (2%)  12343Mi (9%)
  ephemeral-storage  0 (0%)       0 (0%)
  hugepages-1Gi      0 (0%)       0 (0%)
  hugepages-2Mi      0 (0%)       0 (0%)
  mock/gpu           0            0
Events:              <none>
```

可以看出，在Capacity、Allocatable和Allocated resources中均已出现了mock/gpu，说明我们魔改成功。

##### 善后工作

我们下掉刚刚部署的mock-device服务

```
[root@k8s-master01 k8s-device-plugin]# helm uninstall mock-device-plugin
```

发现`kubectl describe node k8s-node01`的返回内容，仍然包括mock/gpu信息。

> 这就尴尬了，kubelet没有自动更新device-plugin的注册情况。

为此，我们可以进行如下操作，恢复k8s的原始状态。

1. [**~~不可行~~**]重置kubelet（此方案不可行）

   ```
   [root@k8s-master01 k8s-device-plugin]# systemctl stop kubelet
   [root@k8s-master01 k8s-device-plugin]# rm -rf /var/lib/kubelet/*
   [root@k8s-master01 k8s-device-plugin]# systemctl start kubelet
   ```

2. [**~~不推荐~~**]鉴于方案1不可行，我十分怀疑是有一些缓存把数据存住了，不如直接删除节点

   ```
   [root@k8s-master01 k8s-device-plugin]# kubectl delete node k8s-node01
   ```

   然后重启k8s-node01的kubelet，这样会重新接入集群

   ```
   [root@k8s-node01 ~]# systemctl restart kubelet
   ```

   待集群恢复后，查询节点状态

   ```
   [root@k8s-master01 k8s-device-plugin]# kubectl describe node k8s-node01
   Name:               k8s-node01
   ...
   ...
   ...
   Addresses:
     InternalIP:  10.206.68.1
     Hostname:    k8s-node01
   Capacity:
     cpu:                40
     ephemeral-storage:  467028168Ki
     hugepages-1Gi:      0
     hugepages-2Mi:      0
     memory:             131661420Ki
     pods:               110
   Allocatable:
     cpu:                40
     ephemeral-storage:  478236844027
     hugepages-1Gi:      0
     hugepages-2Mi:      0
     memory:             131661420Ki
     pods:               110
   ...
   ...
   ...
   Allocated resources:
     (Total limits may be over 100 percent, i.e., overcommitted.)
     Resource           Requests     Limits
     --------           --------     ------
     cpu                2362m (5%)   8610m (21%)
     memory             2873Mi (2%)  12343Mi (9%)
     ephemeral-storage  0 (0%)       0 (0%)
     hugepages-1Gi      0 (0%)       0 (0%)
     hugepages-2Mi      0 (0%)       0 (0%)
   Events:              <none>
   ```

3. [**~~不可行~~**]方案2可行，但是需要delete节点，这是非常危险的操作。

   我们能否直接更改etcd的数据呢？呵，Extended Resources根本没有存在etcd中，此处只是记录下操作

   ```shell
   # 查询跟kubelet有关的数据内容
   [root@k8s-master01 ~]# etcdctl get /registry --prefix --keys-only | grep kubelet
   /registry/clusterrolebindings/kube-apiserver:kubelet-apis
   /registry/clusterrolebindings/kubelet-bootstrap
   /registry/clusterroles/system:certificates.k8s.io:kube-apiserver-client-kubelet-approver
   /registry/clusterroles/system:certificates.k8s.io:kubelet-serving-approver
   /registry/clusterroles/system:kubelet-api-admin
   /registry/endpointslices/kube-system/kubelet-9lx4b
   /registry/events/default/kube-apiserver:kubelet-apis.1766532325dab5b7
   /registry/events/default/kubelet-bootstrap.1766532325d6a99d
   /registry/monitoring.coreos.com/servicemonitors/d3os-monitoring-system/kubelet
   /registry/services/endpoints/kube-system/kubelet
   /registry/services/specs/kube-system/kubelet
   ```

   ```shell
   # 查询/registry/clusterrolebindings/kube-apiserver:kubelet-apis的内容
   [root@k8s-master01 ~]# etcdhelper get /registry/clusterrolebindings/kube-apiserver:kubelet-apis
   rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding
   {
     "kind": "ClusterRoleBinding",
     "apiVersion": "rbac.authorization.k8s.io/v1",
     "metadata": {
       "name": "kube-apiserver:kubelet-apis",
       "uid": "9bd744b3-731c-4e97-9b1a-de272d537e42",
       "creationTimestamp": "2023-04-11T10:10:38Z",
       "managedFields": [
         {
           "manager": "kubectl-create",
           "operation": "Update",
           "apiVersion": "rbac.authorization.k8s.io/v1",
           "time": "2023-04-11T10:10:38Z",
           "fieldsType": "FieldsV1",
           "fieldsV1": {
             "f:roleRef": {
               "f:apiGroup": {},
               "f:kind": {},
               "f:name": {}
             },
             "f:subjects": {}
           }
         }
       ]
     },
     "subjects": [
       {
         "kind": "User",
         "apiGroup": "rbac.authorization.k8s.io",
         "name": "kubernetes"
       }
     ],
     "roleRef": {
       "apiGroup": "rbac.authorization.k8s.io",
       "kind": "ClusterRole",
       "name": "system:kubelet-api-admin"
     }
   }
   ```

4. [**推荐**]k8s官方给出了注册和注销Extended Resources的方法，如下

   ```
   curl --header "Content-Type: application/json-patch+json" \
   --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem
   --request PATCH \
   --data '[{"op": "add", "path": "/status/capacity/mock.com~1gpu", "value": "10"}]' \
   http://<apiserver-ip>:6443/api/v1/nodes/k8s-node1/status
   ```

   ```
   curl --header "Content-Type: application/json-patch+json" \
   --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem
   --request PATCH \
   --data '[{"op": "remove", "path": "/status/capacity/mock.com~1gpu"}]' \
   http://<apiserver-ip>:6443/api/v1/nodes/k8s-node1/status
   ```

   > 上述--cert ./client.pem --key ./client-key.pem --cacert ./ca.pem证书，分别对应/etc/kubernetes/pki/admin.pem、/etc/kubernetes/pki/admin-key.pem和/etc/kubernetes/pki/ca.pem
   >
   > 如果您无法找到这三个文件，可以使用如下命令获得相应文件。
   >
   > grep client-cert ~/.kube/config |cut -d" " -f 6 | base64 -d > ./client.pem
   > grep client-key-data ~/.kube/config |cut -d" " -f 6 | base64 -d > ./client-key.pem
   > grep certificate-authority-data ~/.kube/config |cut -d" " -f 6 | base64 -d > ./ca.pem

### 总结

通过实战mock gpu，基本了解了向k8s 注册device-plugin的机制，接下来要尝试查询kubelet是如何获取api/v1/nodes/k8s-node1/status这个路径下的信息的

# k8s-device-plugin解析

本文对k8s-device-plugin-v1.11版本的工作原理进行解析。

### 基本知识

在本小节中，会对一些基本概念进行说明

##### kubelet_internal_checkpoint

```
[root@XXX device-plugins]# pwd
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


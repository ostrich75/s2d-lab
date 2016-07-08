# Read Me First

## S2D-Lab Pre-Requisite:
- First of all, you need to have machine with Windows Server 2016 TP5 installed. If you want to deploy Hyper-Converged S2D (default option), you need to make sure your hardware support nested virtualization.
- You need to have Domain Controller which attached to a virtual switch (private switch is recommneded if you don't have 10Gb NIC).
- You also need to have DHCP server available in the network of the above virtual switch. (You could co-lo DHCP and DC together.)
 
## S2D-Lab Scripts:
- S2D-LabSetup.ps1 help you provision a set of domain-joined VMs with roles and features required by Storage Space Direct.
- S2D-LabSetup-FullyAutomated help you setup an end-to-end Storage Space Direct environment.

## (Optional) Download link for DC and SysPrepared G2 Image:
You may use 7zip (http://www.7-zip.org/) to unzip the downloaded files.
- Domain Controller

  http://pan.baidu.com/s/1geMpbZt
  
  http://pan.baidu.com/s/1geCfDbd
 
- SysPreped Windows Server 2016 TP5 Gen2 image
  
  http://pan.baidu.com/s/1bpA2gG3

  http://pan.baidu.com/s/1eS9Gd2M

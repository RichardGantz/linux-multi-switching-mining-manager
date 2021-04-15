(shell-command-on-region (point-max) (point-max)
      "nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu,power.default_limit,enforced.power.limit --format=csv,noheader" nil 'insert)
(shell-command-on-region (point-max) (point-max) "/home/avalon/miner/zmminer/zm-0.6.2/zm --list-devices" nil 'insert)

0, Quadro RTX 4000, 00000000:01:00.0, GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f, 1 %, 125.00 W, 100.00 W
1, Graphics Device, 00000000:02:00.0, GPU-000bdf4a-1a2c-db4d-5486-585548cd33cb, 100 %, 170.00 W, 125.00 W
2, GeForce RTX 3070, 00000000:03:00.0, GPU-d4c4b983-7bad-7b90-f140-970a03a97f2d, 100 %, 270.00 W, 125.00 W
3, GeForce RTX 3070, 00000000:04:00.0, GPU-3ce4f7c0-066c-38ac-2ef7-e23fef53af0f, 100 %, 270.00 W, 125.00 W
4, GeForce RTX 3070, 00000000:05:00.0, GPU-2d93bcf7-ca3d-0ca6-7902-664c9d9557f4, 100 %, 270.00 W, 125.00 W
5, GeForce RTX 3070, 00000000:06:00.0, GPU-bd3cdf4a-e1b0-59ef-5dd1-b20e2a43256b, 100 %, 270.00 W, 120.00 W
6, GeForce RTX 3070, 00000000:09:00.0, GPU-50b643a5-f671-3b26-0381-2adea74a7103, 100 %, 270.00 W, 125.00 W
7, GeForce RTX 3070, 00000000:0D:00.0, GPU-5c755a4e-d48e-f85c-43cc-5bdb1f8325cd, 100 %, 270.00 W, 270.00 W

Device: 0    GeForce RTX 3070         MB: 7982  PCI: 3:0
Device: 1    GeForce RTX 3070         MB: 7982  PCI: 4:0
Device: 2    GeForce RTX 3070         MB: 7982  PCI: 5:0
Device: 3    GeForce RTX 3070         MB: 7982  PCI: 6:0
Device: 4    GeForce RTX 3070         MB: 7982  PCI: 9:0
Device: 5    GeForce RTX 3070         MB: 7982  PCI: 13:0
Device: 6    Graphics Device          MB: 12053 PCI: 2:0
Device: 7    Quadro RTX 4000          MB: 7981  PCI: 1:0

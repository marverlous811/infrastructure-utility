# Vault Scripts

## Docker profiles

Lưu thông tin đăng nhập Docker registry trong Vault và chuyển qua lại giữa các profile. Mỗi profile có một `DOCKER_CONFIG` riêng trong `~/.docker-profiles/<profile>`.

- `docker-registry.sh`: lưu profile (registry, username, token) vào Vault.
- `docker-profile.sh`: liệt kê profile, login bằng một profile.

### Yêu cầu

- `bash`, `docker`
- Vault CLI >= 1.11 (cần cờ `-mount=`), đã đăng nhập (`VAULT_ADDR` đã set, `vault login` thành công)

### Cài đặt

**1. Copy script vào `PATH`**

Chạy lệnh này trong thư mục `scripts/vaults`:

```bash
sudo mkdir -p /usr/local/bin   # macOS Apple Silicon có thể chưa có sẵn thư mục này
sudo install -m 755 docker-registry.sh /usr/local/bin/docker-registry
sudo install -m 755 docker-profile.sh /usr/local/bin/docker-profile
```

Lệnh này chạy được trên cả macOS và Ubuntu. Tên lệnh sau khi cài không có đuôi `.sh`, vì hàm `dprofile` ở bước 2 gọi `docker-profile`.

Nếu không muốn dùng `sudo`, có thể copy vào `~/.local/bin`. Ubuntu thường đã có thư mục này trong `PATH`. Trên macOS phải tự thêm `export PATH="$HOME/.local/bin:$PATH"` vào `~/.zshrc`.

Kiểm tra:

```bash
command -v docker-registry docker-profile
```

**2. Thêm hàm `dprofile` vào shell**

Script chạy trong process con nên không đổi được `DOCKER_CONFIG` của shell đang dùng. Hàm dưới đây sẽ làm việc đó.

Thêm vào cuối `~/.zshrc` (macOS, zsh là shell mặc định) hoặc `~/.bashrc` (Ubuntu):

```bash
dprofile() {
  case "$1" in
    use)
      docker-profile use "$2" || return $?
      export DOCKER_CONFIG="$HOME/.docker-profiles/$2"
      ;;
    current)
      echo "${DOCKER_CONFIG:-$HOME/.docker}"
      ;;
    default)
      unset DOCKER_CONFIG
      ;;
    *)
      docker-profile "$@"
      ;;
  esac
}
```

Sau đó nạp lại cấu hình shell:

```bash
source ~/.zshrc    # hoặc: source ~/.bashrc
```

### Sử dụng

```bash
# Lưu profile: docker-registry <profile> [username] [registry]
docker-registry dockerhub-personal myuser                # registry mặc định là docker.io
docker-registry ghcr-work myuser ghcr.io
docker-registry ghcr-work "" ghcr.io                     # để trống username thì script sẽ hỏi

dprofile list                  # liệt kê các profile trong Vault
dprofile use ghcr-work         # login và chuyển shell hiện tại sang profile này
dprofile current               # in DOCKER_CONFIG đang dùng
dprofile default               # quay về ~/.docker
```

Tên profile chỉ được chứa `a-z A-Z 0-9 _ -`.

### Biến môi trường

| Biến                  | Mặc định          | Ý nghĩa                    |
| --------------------- | ----------------- | -------------------------- |
| `DOCKER_VAULT_MOUNT`  | `secret`          | KV mount trong Vault       |
| `DOCKER_VAULT_PREFIX` | `docker/profiles` | Đường dẫn chứa các profile |

### Lưu ý

- Token được lưu trong `~/.docker-profiles/<profile>/config.json` dạng base64, file có quyền 600. Script cố ý không dùng keychain hay `pass`, vì hai công cụ này lưu token theo tên registry, nên hai profile cùng registry sẽ ghi đè lẫn nhau.
- `cli-plugins` và `contexts` của `~/.docker` được symlink vào từng profile, để `docker compose`, `buildx` và context của Docker Desktop vẫn dùng được.

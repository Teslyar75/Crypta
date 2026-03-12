# Задания Azure VM — Пошаговые инструкции

## Задание 1: Две VM (Linux + Windows) в своей группе ресурсов

### Шаг 1: Вход и переменные

```bash
az login
```

```bash
# Задай своё имя (латиница, без пробелов)
RESOURCE_GROUP="my-vm-rg"
LOCATION="eastus"
LINUX_VM="linux-vm"
WINDOWS_VM="windows-vm"
ADMIN_USER="azureuser"
ADMIN_PASSWORD="YourSecurePassword123!"
```

### Шаг 2: Создание группы ресурсов

```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Шаг 3: Создание Linux VM (Ubuntu)

```bash
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $LINUX_VM \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --authentication-type password \
  --admin-password $ADMIN_PASSWORD \
  --public-ip-sku Standard
```

### Шаг 4: Создание Windows VM

```bash
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $WINDOWS_VM \
  --image Win2022AzureEditionCore \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --admin-password $ADMIN_PASSWORD \
  --public-ip-sku Standard
```

### Шаг 5: Открытие портов (для RDP и SSH)

```bash
# RDP для Windows (порт 3389)
az vm open-port --port 3389 --resource-group $RESOURCE_GROUP --name $WINDOWS_VM

# SSH для Linux (порт 22) — обычно уже открыт
az vm open-port --port 22 --resource-group $RESOURCE_GROUP --name $LINUX_VM
```

### Шаг 6: Подключение к VM

**Linux (SSH):**
```bash
# Получить публичный IP
az vm show -d -g $RESOURCE_GROUP -n $LINUX_VM --query publicIps -o tsv

# Подключиться (подставь IP из команды выше)
ssh azureuser@<LINUX_VM_IP>
# Пароль: YourSecurePassword123!
```

**Windows (RDP):**
```bash
# Получить публичный IP
az vm show -d -g $RESOURCE_GROUP -n $WINDOWS_VM --query publicIps -o tsv
```

Затем на своём ПК:
1. Win + R → `mstsc` → Enter
2. Ввести IP из команды выше
3. Логин: `azureuser`, пароль: `YourSecurePassword123!`

---

## Задание 2: VM через Cloud Shell

### Вариант A: Одна Linux VM

```bash
az login

# Создание группы ресурсов
az group create --name cloudshell-vm-rg --location eastus

# Создание VM
az vm create \
  --resource-group cloudshell-vm-rg \
  --name cloudshell-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --authentication-type password \
  --admin-password "CloudShellVM123!" \
  --public-ip-sku Standard
```

### Вариант B: Через портал (для скриншота процесса)

1. В Azure Cloud Shell выполни:
```bash
az vm create \
  --resource-group cloudshell-vm-rg \
  --name my-cloud-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys
```

2. Сделай скриншот консоли во время выполнения.

---

## Важные замечания

- **Пароль**: Должен содержать: заглавные, строчные, цифры, спецсимволы. Пример: `MyPass123!`
- **Размер Standard_B1s**: Бесплатный (в рамках Free Tier) или очень дешёвый.
- **Регион**: `eastus` — часто есть в Free Tier. Можно заменить на `westeurope`.

---

## Удаление ресурсов (после сдачи задания)

```bash
az group delete --name my-vm-rg --yes --no-wait
az group delete --name cloudshell-vm-rg --yes --no-wait
```

# Crypta DApp

Децентралізований застосунок (DApp) на базі Ethereum.

## Структура

```
DAPP/
├── contracts/     # Solidity смарт-контракти
├── scripts/       # Скрипти деплою
├── src/           # React фронтенд (Vite)
├── test/          # Тести контрактів
└── index.html
```

## Встановлення

```bash
cd DAPP
npm install
```

## Запуск

```bash
# Фронтенд (dev-сервер)
npm run dev

# Компіляція контрактів
npm run compile

# Тести
npm run test

# Деплой (локальна мережа)
npx hardhat node
npm run deploy
```

## Forum (HTML)

Стандартна HTML-сторінка для роботи з контрактом Forum:

1. Запустіть `npm run dev`
2. Відкрийте http://localhost:5173/forum.html
3. Підключіть MetaMask
4. Введіть адресу задеплоєного контракту Forum
5. Створюйте пости та переглядайте їх

## Підключення MetaMask

1. Встановіть MetaMask
2. Додайте мережу: localhost:8545 (Hardhat)
3. Імпортуйте тестовий акаунт

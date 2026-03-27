# Lesson 8 — DApp Forum (Ethereum)

## Завдання

1. **Верстка** — картки постів, секції для створення посту та списку.
2. **Події** — підписка на `PostCreated`, `PostRemoved`, `PostLiked`, `PostUnliked`, `PostsCleared`; після кожної події — оновлення списку постів.
3. **Фільтр автора** — усі пости / лише мої / пости конкретного автора за адресою `0x…`.
4. **Видалення** — лише автор поста (кнопка «Видалити»); у контракті `remove_post` перевіряє `msg.sender == author`.
5. **Лайки** — `like_post` / `unlike_post`, відображення лічильника.
6. **UI** — темна тема, інпути, кнопки, картки з рамкою та тінню.

## Структура

```
Lesson 8/DAPP/
├── contracts/forum.sol
├── public/contract-addresses.json   # після deploy:forum
├── scripts/deploy-forum.js
├── src/App.jsx
├── src/main.jsx
└── package.json
```

## Запуск

```bash
cd HomeWorkCrypta/Lesson 8/DAPP
npm install
npm run compile
npm run deploy:forum
npm run dev
```

Відкрийте http://localhost:5173 і підключіть MetaMask до мережі Hardhat (`localhost:8545`, chainId `31337`).

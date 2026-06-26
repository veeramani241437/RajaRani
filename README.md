# 👑 RajaRani (King & Queen)

[![Live Demo](https://img.shields.io/badge/Demo-Live_Now-success?style=for-the-badge&logo=google-chrome&logoColor=white)](https://veeramani241437.github.io/RajaRani/)
[![Flutter](https://img.shields.io/badge/Flutter-v3.35+-blue?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database-emerald?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)

Welcome to **RajaRani**, the ultimate real-time multiplayer social guessing game of strategy, deception, and deduction! Inspired by classic Indian parlor games like *Raja Mantri Chor Sipahi*, RajaRani brings this timeless experience online, allowing friends to play together on mobile and desktop browsers instantly.

---

## ⚡ Play Live Right Now!

No downloads or setups are needed. Share this link with your friends, create a room, and start playing:

👉 **[Enjoy the RajaRani game in real time using this link!](https://veeramani241437.github.io/RajaRani/)** 🎮

---

## 🌟 The Game Concept

Players are randomly assigned secret roles, ranging from the highest-ranking **King** to the lowest-ranking **Thief**. The game progresses dynamically through a chain of accusations and guesses where players must suspect each other's identity to secure their points.

### 🎭 Role Hierarchy & Points

| Character | Points | Target (Who they must suspect) |
| :--- | :--- | :--- |
| **👑 KING** | 1000 | Automatically revealed at start |
| **👸 QUEEN** | 900 | Prince (if 5 players), Police (if 4 players) |
| **🤴 PRINCE** | 800 | Commander / Police (depending on player count) |
| **🛡️ COMMANDER** | 700 | Minister / Police (depending on player count) |
| **💼 MINISTER** | 600 | Soldier / Police (depending on player count) |
| **⚔️ SOLDIER** | 500 | Merchant / Police (depending on player count) |
| **🛒 MERCHANT** | 300 | Citizen / Police (depending on player count) |
| **🏘️ CITIZEN** | 200 | Police |
| **👮 POLICE** | 100 | Thief |
| **👤 THIEF** | 0 | None (Must remain hidden!) |

*Note: The target chain dynamically scales based on the number of players (supports 4 to 10 players).*

---

## 🔥 Key Features

- **Real-Time Synchronized Rooms**: Create private game rooms with custom round limits. Powered by **Supabase Real-Time Broadcasts**.
- **Dynamic Suspect Chain**: The target guessing flows change automatically depending on the number of players in the room.
- **Premium Aesthetics & Micro-Animations**:
  - Sleek dark theme with golden accent details.
  - Interactive player avatars and card flipping transitions.
  - Spectacular **firecracker explosions** and **3D star particles** celebrate the winners at the end of the final round.
- **Mobile-Responsive Design**: Scaled perfectly to feel like a native app on iOS Safari, Android Chrome, and Desktop browsers.
- **Live Leaderboard**: Re-orders players automatically after each round based on accumulated points.

---

## 🚀 How to Run Locally

If you want to run this project on your machine, follow these steps:

### Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable).
- Set up a free [Supabase](https://supabase.com) project with database tables.

### Setup Steps
1. Clone this repository:
   ```bash
   git clone https://github.com/veeramani241437/RajaRani.git
   cd RajaRani
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run -d chrome
   ```

---

## 🛠️ Technology Stack

- **Frontend**: Flutter Web & Mobile (Dart)
- **Database & Realtime**: Supabase (PostgreSQL with custom functions/triggers)
- **State Sync**: Realtime Database presence listeners

---

## 📜 Database Schema & Functions

All database configurations are detailed in `schema.sql`. Simply run these queries in your Supabase SQL editor to deploy the game logic instantly!

---

*Made with ❤️ by [veeramani241437](https://github.com/veeramani241437).*

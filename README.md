# 🪙 Token Presale Smart Contract

Contrato inteligente descentralizado desarrollado en **Solidity** y probado con **Foundry**, diseñado para gestionar preventas de tokens multi-fase con soporte para pagos en monedas estables (USDT/USDC) y Ethereum (ETH) mediante oráculos de precios de Chainlink.

---

## 🚀 Características Principales

- **Gestión Multi-Fase:** Transición automática de fases basada en volumen de tokens vendidos (`totalSold`) o marcas de tiempo (`endingTime`).
- **Pagos Flexibles:** 
  - Permite comprar con stablecoins (USDT y USDC) manejando de forma dinámica las diferencias de decimales (`decimals()`).
  - Permite comprar con ETH nativo calculando su valor en tiempo real a través de un Price Feed de **Chainlink**.
- **Seguridad y Control:**
  - Integración con librerías de **OpenZeppelin** (`Ownable`, `SafeERC20`).
  - Sistema de lista negra (`isBlacklisted`) para restringir direcciones maliciosas.
  - Mecanismo de `claim` para que los usuarios reclamen sus tokens de forma segura una vez finalizada la preventa.
- **Funciones de Emergencia:** Retiros administrativos seguros para tokens y ETH en caso de contingencia.

---

## 🛠️ Stack Tecnológico

- **Lenguaje:** Solidity (`^0.8.24`)
- **Framework de Pruebas:** Foundry (`forge`, `cast`, `anvil`)
- **Librerías de Seguridad:** OpenZeppelin Contracts

---

## 🧪 Pruebas y Cobertura (Testing & Coverage)

Este proyecto cuenta con una suite de pruebas robusta desarrollada en Foundry.

### 1. Compilar el contrato
```shell
forge build

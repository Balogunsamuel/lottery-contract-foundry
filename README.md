# Raffle smart rcontract

A provably random smart contract lottery

# About

This is a Solidity contract written for a raffle application that uses Chainlink's Verifiable Random Function (VRF) to select a winner, where users can enter by paying an entrance fee, then the chainlink VRF is used to provide a verifiably random selection of a winner. The contract is well-documented and organized for clarity and transparency in its operations.

## Quickstart

To get started with this project, follow the instructions below:

### 1. Clone the Repository

```bash
git clone https://github.com/Balogunsamuel/lottery-contract-foundry

```

# 2. Change to the Project Directory

```bash
cd foundry-smart-contract-lottery-f23

```

# 3. Build the Project

```bash
forge build

```

## What we want it to do??

1. Users can enter by paying for a ticket using eth
   1. The ticket fees are going to go the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. and this will be programmatically with the code.
3. Using Chainlink VRF & Chainlink automation
   1. Chainlink VRF -> **Randomness**
   2. Chainlink Automation -> Time based trigger durin the course of the raffle

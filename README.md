# Time-Locked Savings Vault Smart Contract

A secure, time-locked savings contract built on the Stacks blockchain using Clarity. This contract allows users to create personal savings vaults that lock their STX tokens for a specified period, preventing early withdrawal and encouraging disciplined saving habits.

## Features

- **Time-Locked Savings**: Create savings accounts with customizable lock periods
- **Secure Fund Management**: STX tokens are securely held in the contract until unlock time
- **Flexible Deposits**: Add funds to your vault at any time during the lock period
- **Controlled Withdrawals**: Funds can only be withdrawn after the lock period expires
- **Lock Extension**: Extend your lock period (cannot be reduced for security)
- **Emergency System**: Optional emergency withdrawals with penalty (owner-controlled)
- **Event Logging**: Complete audit trail of all vault activities
- **Multiple Vault Support**: Each user can have one personal vault

## Contract Overview

### Core Functionality

The contract manages individual savings vaults for users, where each vault contains:
- **Balance**: Amount of STX locked in the vault
- **Unlock Time**: Block height when funds become available
- **Created At**: Timestamp of vault creation

### Time Mechanics

The contract uses Stacks block heights for timing:
- Minimum lock period: 144 blocks (~24 hours)
- Each block represents approximately 10 minutes on Stacks mainnet
- Lock times are based on block heights, not wall-clock time

## Public Functions

### Vault Management

#### `create-vault(unlock-delay)`
Creates a new savings vault with a specified lock period.
- **Parameters**: `unlock-delay` (uint) - Number of blocks to lock funds
- **Minimum**: 144 blocks (~24 hours)
- **Returns**: Unlock time (block height)
- **Restrictions**: One vault per user

```clarity
(contract-call? .savings-vault create-vault u1008) ;; Lock for ~1 week
```

#### `deposit(amount)`
Deposits STX tokens into your existing vault.
- **Parameters**: `amount` (uint) - Amount of STX to deposit (in microSTX)
- **Returns**: New vault balance
- **Requirements**: Must have an existing vault

```clarity
(contract-call? .savings-vault deposit u1000000) ;; Deposit 1 STX
```

### Withdrawals

#### `withdraw(amount)`
Withdraws a specific amount from your vault after the lock period.
- **Parameters**: `amount` (uint) - Amount to withdraw (in microSTX)
- **Returns**: Remaining vault balance
- **Requirements**: Vault must be unlocked, sufficient balance

```clarity
(contract-call? .savings-vault withdraw u500000) ;; Withdraw 0.5 STX
```

#### `withdraw-all()`
Withdraws all funds from your vault.
- **Returns**: Final vault balance (should be 0)
- **Requirements**: Vault must be unlocked

```clarity
(contract-call? .savings-vault withdraw-all)
```

### Advanced Features

#### `extend-lock(additional-delay)`
Extends the lock period of your vault (security feature - cannot reduce time).
- **Parameters**: `additional-delay` (uint) - Additional blocks to extend lock
- **Returns**: New unlock time
- **Use Case**: Extend savings discipline or security

```clarity
(contract-call? .savings-vault extend-lock u144) ;; Extend by 1 day
```

#### `emergency-withdraw(amount)`
Emergency withdrawal with 10% penalty (only if enabled by contract owner).
- **Parameters**: `amount` (uint) - Amount to withdraw
- **Returns**: Net amount received (after 10% penalty)
- **Requirements**: Emergency mode enabled, sufficient balance

```clarity
(contract-call? .savings-vault emergency-withdraw u1000000) ;; Emergency withdraw 1 STX
```

### Admin Functions

#### `toggle-emergency(enabled)`
Enables or disables emergency withdrawals (contract owner only).
- **Parameters**: `enabled` (bool) - Enable/disable emergency withdrawals
- **Returns**: New emergency status

## Read-Only Functions

### Vault Information

#### `get-vault-info(owner)`
Returns complete vault information for a user.
```clarity
(contract-call? .savings-vault get-vault-info 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
;; Returns: {balance: u1000000, unlock-time: u2000, created-at: u1856}
```

#### `is-vault-unlocked(owner)`
Checks if a vault's funds are currently available for withdrawal.
```clarity
(contract-call? .savings-vault is-vault-unlocked 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
;; Returns: true or false
```

#### `time-until-unlock(owner)`
Returns the number of blocks remaining until unlock (0 if already unlocked).
```clarity
(contract-call? .savings-vault time-until-unlock 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
;; Returns: u144 (blocks remaining)
```

### Contract Statistics

#### `get-total-locked-funds()`
Returns the total amount of STX locked across all vaults.

#### `get-contract-balance()`
Returns the contract's total STX balance.

#### `get-vault-event(event-id)`
Retrieves a specific vault event by ID for audit purposes.

## Error Codes

- **ERR-NOT-AUTHORIZED (100)**: Unauthorized access or action
- **ERR-INVALID-AMOUNT (101)**: Invalid amount specified (must be > 0)
- **ERR-FUNDS-LOCKED (102)**: Attempted withdrawal before unlock time
- **ERR-NO-VAULT-FOUND (103)**: No vault exists for the user
- **ERR-INSUFFICIENT-BALANCE (104)**: Insufficient vault balance
- **ERR-INVALID-UNLOCK-TIME (105)**: Invalid unlock time specified

## Usage Examples

### Creating and Using a Savings Vault

```clarity
;; 1. Create a vault locked for 1 week (1008 blocks)
(contract-call? .savings-vault create-vault u1008)

;; 2. Deposit 5 STX into the vault
(contract-call? .savings-vault deposit u5000000)

;; 3. Check vault status
(contract-call? .savings-vault get-vault-info tx-sender)

;; 4. Check if unlocked (after 1 week)
(contract-call? .savings-vault is-vault-unlocked tx-sender)

;; 5. Withdraw all funds when unlocked
(contract-call? .savings-vault withdraw-all)
```

### Extending Lock Period

```clarity
;; Extend current lock by another 3 days (432 blocks)
(contract-call? .savings-vault extend-lock u432)
```

## Security Features

- **Time Lock Enforcement**: Funds cannot be withdrawn before unlock time
- **Single Vault Limitation**: Prevents complex state management issues
- **Input Validation**: All parameters are validated before execution
- **Emergency Controls**: Owner can enable/disable emergency features
- **Event Logging**: Complete audit trail of all activities
- **Penalty System**: 10% penalty for emergency withdrawals discourages misuse

## Deployment

1. Deploy the contract to Stacks testnet or mainnet
2. The deploying address becomes the contract owner
3. Users can immediately start creating vaults
4. Emergency withdrawals are disabled by default

## Testing

Before mainnet deployment, thoroughly test:
- Vault creation with various lock periods
- Deposit and withdrawal functionality
- Time lock enforcement
- Edge cases (zero amounts, non-existent vaults)
- Emergency withdrawal system
- Event logging accuracy

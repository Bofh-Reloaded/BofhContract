# Multi-Sig Wallet Setup Guide

**Project**: BofhContract V2
**Version**: v1.5.0
**Last Updated**: 2025-11-11
**Target**: Production Mainnet Deployment

## Table of Contents

1. [Why Multi-Sig?](#why-multi-sig)
2. [Recommended Solutions](#recommended-solutions)
3. [Gnosis Safe Setup (Recommended)](#gnosis-safe-setup-recommended)
4. [Ownership Transfer Process](#ownership-transfer-process)
5. [Multi-Sig Operations](#multi-sig-operations)
6. [Security Best Practices](#security-best-practices)
7. [Emergency Procedures](#emergency-procedures)

---

## Why Multi-Sig?

### Risks of Single Owner

BofhContractV2 inherits significant control through the `onlyOwner` modifier:

**Owner Capabilities:**
- Update risk parameters (maxTradeVolume, minPoolLiquidity, etc.)
- Configure MEV protection settings
- Blacklist/whitelist pools
- Pause/unpause contract
- Transfer ownership
- Emergency token recovery

**Single Owner Risks:**
1. **Private Key Compromise**: Single point of failure
2. **Rogue Owner**: No checks and balances
3. **Loss of Access**: No recovery mechanism
4. **Regulatory Exposure**: Centralized control
5. **Trust Issues**: Users must trust single entity

### Benefits of Multi-Sig

 **Distributed Security**: 3-of-5, 4-of-7, etc. reduces key compromise risk
**Accountability**: All changes require multiple approvals
 **Transparency**: All transactions visible on-chain
 **Recovery**: Loss of 1-2 keys doesn't halt operations
 **Decentralization**: Shared governance model

---

## Recommended Solutions

### 1. Gnosis Safe (Recommended) PPPPP

**Why Gnosis Safe:**
- Industry standard (protects $100B+ in assets)
- Native BSC support
- Battle-tested security
- Rich transaction UI
- Free to use
- Active community

**Chains Supported:**
-  BSC Mainnet: https://safe.bnbchain.org
-  BSC Testnet: https://testnet.safe.bnbchain.org
-  Ethereum, Polygon, Arbitrum, etc.

**Features:**
- M-of-N signature threshold
- WalletConnect integration
- Hardware wallet support (Ledger, Trezor)
- Transaction batching
- Address book
- Spending limits
- Mobile app (iOS/Android)

**Cost**: Free (only gas fees)

### 2. Alternative Solutions

#### Safe Wallet (formerly Gnosis Safe)
- Official rebrand of Gnosis Safe
- Same security, new branding
- https://safe.global

#### Multis
- Modern multi-sig interface
- Supports BSC
- Enterprise features
- https://multis.co

#### Fireblocks (Enterprise)
- Institutional-grade security
- MPC (Multi-Party Computation) technology
- High cost ($$$)
- https://fireblocks.com

---

## Gnosis Safe Setup (Recommended)

### Prerequisites

1. **Signers Identified**: 3-7 trusted individuals/entities
2. **Threshold Decided**: Typically 60-70% (3-of-5, 4-of-7, etc.)
3. **Wallets Prepared**: Each signer needs a wallet (MetaMask, Ledger, etc.)
4. **BNB for Gas**: ~0.1 BNB for Safe creation + operations

### Step 1: Create Gnosis Safe

#### 1.1 Navigate to Safe App

**Testnet (for practice)**:
```
https://testnet.safe.bnbchain.org
```

**Mainnet (production)**:
```
https://safe.bnbchain.org
```

#### 1.2 Connect Wallet

- Click "Connect Wallet"
- Choose wallet provider (MetaMask recommended)
- Approve connection
- Ensure you're on BSC network (Chain ID: 56 for mainnet, 97 for testnet)

#### 1.3 Create New Safe

1. Click "+ Create New Safe"
2. Select "BSC" network
3. Name your Safe (e.g., "BofhContract Mainnet Multisig")

#### 1.4 Add Signers

**Example 5-of-7 Setup**:

```
Signer 1: Lead Developer (Alice)
Address: 0xAlice...

Signer 2: Smart Contract Engineer (Bob)
Address: 0xBob...

Signer 3: Security Auditor (Charlie)
Address: 0xCharlie...

Signer 4: Operations Lead (Diana)
Address: 0xDiana...

Signer 5: Community Representative (Eve)
Address: 0xEve...

Signer 6: Legal Advisor (Frank)
Address: 0xFrank...

Signer 7: Backup Developer (Grace)
Address: 0xGrace...

Threshold: 5 out of 7 signatures required
```

**Threshold Recommendations**:
- **3-of-5**: Good balance (60% consensus)
- **4-of-7**: More secure (57% consensus)
- **5-of-9**: Very secure (56% consensus)

  **Important**: Higher thresholds = more secure but slower operations

#### 1.5 Review & Deploy

1. Review signer list
2. Confirm threshold
3. Click "Create"
4. Sign transaction with your wallet
5. Wait for deployment (~30-60 seconds)
6. **Save Safe address**: `0xYourSafe...`

### Step 2: Fund the Safe

Transfer gas funds (BNB) to the Safe address:

```bash
# Testnet: Get from faucet
https://testnet.binance.org/faucet-smart

# Mainnet: Transfer 0.5-1 BNB
# (enough for 20-30 operations)
```

### Step 3: Verify Safe Setup

1. Visit Safe dashboard
2. Check "Assets" tab (should show BNB balance)
3. Check "Settings" ’ "Owners" (verify all signers)
4. Check "Settings" ’ "Policies" (verify threshold)

### Step 4: Test Transaction (Optional)

**Testnet only** - Practice with a simple transaction:

1. Go to "New Transaction"
2. Choose "Contract Interaction"
3. Enter BofhContract address
4. Select `isPaused()` function (read-only test)
5. Submit transaction
6. Get 4 other signers to approve
7. Execute transaction

---

## Ownership Transfer Process

### Prerequisites Checklist

- [ ] Multi-sig Safe created and funded
- [ ] All signers have access and tested signing
- [ ] BofhContract deployed and verified on BSCScan
- [ ] Current owner wallet accessible
- [ ] 24-hour announcement made to community
- [ ] Emergency rollback plan documented

### Step 1: Announce Ownership Transfer

**Recommendation**: Announce 24-48 hours in advance

```
=â BofhContract V2 Ownership Transfer

We will be transferring ownership of BofhContractV2 to a
5-of-7 multi-sig wallet for enhanced security and decentralization.

Current Owner: 0xCurrentOwner...
New Multi-Sig: 0xGnosisSafe...

Timeline: [DATE] at [TIME] UTC
Duration: ~10 minutes
Expected Downtime: None

Signers:
1. Lead Developer (Alice)
2. Smart Contract Engineer (Bob)
3. Security Auditor (Charlie)
4. Operations Lead (Diana)
5. Community Representative (Eve)
6. Legal Advisor (Frank)
7. Backup Developer (Grace)

Threshold: 5 out of 7 signatures required for any changes
```

### Step 2: Transfer Ownership Transaction

#### Method A: Using Hardhat Console (Recommended)

```bash
npx hardhat console --network bscMainnet
```

```javascript
// Get contract instance
const bofhAddress = "0xYourDeployedBofhContract";
const BofhContract = await ethers.getContractFactory("BofhContractV2");
const bofh = BofhContract.attach(bofhAddress);

// Verify current owner
const currentOwner = await bofh.admin();
console.log("Current Owner:", currentOwner);

// Verify signer is current owner
const [signer] = await ethers.getSigners();
console.log("Signer:", signer.address);
if (currentOwner.toLowerCase() !== signer.address.toLowerCase()) {
  throw new Error("Signer is not current owner!");
}

// New multi-sig address
const newOwner = "0xYourGnosisSafeAddress";

// Transfer ownership
console.log("\n= Transferring ownership to:", newOwner);
const tx = await bofh.transferOwnership(newOwner);
console.log("Transaction hash:", tx.hash);

// Wait for confirmation
console.log("Waiting for confirmation...");
const receipt = await tx.wait();
console.log(" Transaction confirmed in block:", receipt.blockNumber);

// Verify new owner
const verifyOwner = await bofh.admin();
console.log("New Owner:", verifyOwner);
console.log("Match:", verifyOwner.toLowerCase() === newOwner.toLowerCase());
```

#### Method B: Using BSCScan (Alternative)

1. Go to BSCScan contract page: `https://bscscan.com/address/0xYourContract#writeContract`
2. Click "Connect to Web3"
3. Connect current owner wallet
4. Find `transferOwnership` function
5. Enter new owner (Gnosis Safe address): `0xYourSafe...`
6. Click "Write"
7. Confirm transaction in wallet
8. Wait for confirmation

### Step 3: Verify Ownership Transfer

```bash
npx hardhat console --network bscMainnet
```

```javascript
const bofhAddress = "0xYourDeployedBofhContract";
const bofh = await ethers.getContractAt("BofhContractV2", bofhAddress);

const owner = await bofh.admin();
console.log("Current Owner:", owner);
console.log("Expected Safe:", "0xYourSafeAddress");
console.log("Match:", owner.toLowerCase() === "0xYourSafeAddress".toLowerCase());
```

### Step 4: Test Multi-Sig Operations

Perform a simple operation to verify multi-sig works:

**Test: Check isPaused status**

1. Go to Gnosis Safe UI
2. Click "New Transaction"
3. Choose "Contract Interaction"
4. Enter BofhContract address
5. Paste ABI or import from BSCScan
6. Select `isPaused()` function
7. Create transaction
8. Get threshold approvals (5 in 5-of-7 setup)
9. Execute transaction
10. Verify result

### Step 5: Announce Completion

```
 BofhContract V2 Ownership Transfer Complete

Ownership successfully transferred to multi-sig wallet.

Transaction: 0xTransactionHash...
Block: [BLOCK_NUMBER]
Timestamp: [TIMESTAMP]

New Owner (Multi-Sig): 0xGnosisSafeAddress...
Threshold: 5-of-7 signatures

All future parameter changes will require approval from
5 of 7 signers, ensuring decentralized governance.

View on BSCScan: https://bscscan.com/tx/0xTransactionHash...
View Safe: https://safe.bnbchain.org/home?safe=bsc:0xYourSafe
```

---

## Multi-Sig Operations

### Common Operations via Multi-Sig

#### 1. Update Risk Parameters

**When**: Market conditions change, volume increases

```javascript
// In Gnosis Safe UI:
Contract: 0xBofhContractAddress
Function: updateRiskParams(uint256,uint256,uint256,uint256)

Parameters:
- maxTradeVolume: 2000000000 (2000 * 1e6)
- minPoolLiquidity: 200000000 (200 * 1e6)
- maxPriceImpact: 15 (15%)
- sandwichProtectionBips: 75 (0.75%)
```

**Process**:
1. Proposer creates transaction in Safe UI
2. Proposer provides rationale (off-chain or in Safe notes)
3. 5 signers review and approve
4. Last signer executes transaction
5. Contract emits `RiskParamsUpdated` event

#### 2. Configure MEV Protection

**When**: Flash loan attacks detected

```javascript
Function: configureMEVProtection(bool,uint256,uint256)

Parameters:
- enabled: true
- maxTxPerBlock: 3
- minTxDelay: 12 (seconds)
```

#### 3. Blacklist Suspicious Pool

**When**: Pool exhibits malicious behavior

```javascript
Function: setPoolBlacklist(address,bool)

Parameters:
- poolAddress: 0xSuspiciousPool...
- blacklisted: true
```

#### 4. Emergency Pause

**When**: Critical vulnerability discovered

```javascript
Function: pause()

Parameters: (none)
```

  **Warning**: This stops ALL swaps. Use only in emergencies.

#### 5. Unpause After Fix

**When**: Vulnerability patched, ready to resume

```javascript
Function: unpause()

Parameters: (none)
```

#### 6. Emergency Token Recovery

**When**: Tokens stuck in contract due to bug

```javascript
Function: emergencyTokenRecovery(address,address,uint256)

Parameters:
- tokenAddress: 0xStuckToken...
- recipient: 0xRecoveryAddress...
- amount: 1000000000000000000 (1 token with 18 decimals)
```

  **Note**: Contract must be paused first

### Multi-Sig Transaction Workflow

```
                                         
 1. Proposer Creates Transaction         
    - Selects function                   
    - Enters parameters                  
    - Provides rationale                 
            ,                            
             
             ¼
                                         
 2. Signers Review & Approve             
    - Check function & parameters        
    - Verify rationale                   
    - Simulate transaction (optional)    
    - Approve or Reject                  
            ,                            
             
             ¼
                                         
 3. Threshold Met (5 of 7)               
    - Transaction ready to execute       
    - Any signer can execute             
            ,                            
             
             ¼
                                         
 4. Executor Submits Transaction         
    - Pays gas fee                       
    - Transaction executed on-chain      
            ,                            
             
             ¼
                                         
 5. Verify Execution                     
    - Check transaction success          
    - Verify event emission              
    - Update documentation               
                                         
```

### Batching Multiple Operations

**Use Case**: Update multiple parameters at once

1. In Gnosis Safe, click "New Transaction"
2. Select "Transaction Builder"
3. Add multiple transactions:
   - updateRiskParams(...)
   - configureMEVProtection(...)
   - setPoolBlacklist(...)
4. Review batch
5. Get approvals
6. Execute all in single transaction

**Benefits**:
- Single approval process
- Lower gas costs
- Atomic execution (all-or-nothing)

---

## Security Best Practices

### Signer Selection

 **DO:**
- Choose geographically distributed signers
- Include technical and non-technical members
- Rotate signers periodically (annual review)
- Document each signer's role
- Use hardware wallets (Ledger, Trezor)
- Test signing capability before going live

L **DON'T:**
- Use all signers from same organization
- Give signer access to people who left team
- Use hot wallets for high-value multi-sigs
- Share private keys between signers
- Use untested wallets

### Signer Security

**Each Signer Should**:
1. Use hardware wallet (Ledger Nano X/S, Trezor)
2. Enable 2FA on all accounts
3. Use strong, unique passwords (password manager)
4. Keep seed phrase in secure location (metal backup)
5. Never share private keys
6. Regularly update wallet firmware
7. Use dedicated device for signing (not daily driver)

**Seed Phrase Storage**:
-  Metal seed phrase backup (fire/water resistant)
-  Safe deposit box
-  Encrypted USB drive in secure location
- L Cloud storage (Google Drive, iCloud)
- L Email or messaging apps
- L Plain text file on computer

### Communication Security

**For Coordination**:
- Use encrypted chat (Signal, Wire)
- Verify signer identities (voice call, video)
- Use code words for emergency situations
- Document all decisions in shared secure drive
- Regular signer meetings (monthly recommended)

**For Emergencies**:
- Establish 24/7 contact protocol
- Use secure communication channels only
- Have backup communication method
- Practice emergency drills (quarterly)

### Access Control

**Safe Dashboard Access**:
- Each signer has own wallet (no shared wallets)
- Use view-only mode for non-signers (observers)
- Regularly audit Safe activity logs
- Monitor for unauthorized transaction attempts

**Revoke Compromised Signer**:

If a signer's wallet is compromised:

1. Emergency meeting with other signers
2. Create transaction to remove compromised signer
3. Get threshold approvals (without compromised signer)
4. Add replacement signer in same transaction
5. Notify community
6. Investigate compromise source

### Transaction Verification

Before signing ANY transaction:

1.  Verify contract address matches deployment
2.  Check function selector is correct
3.  Review all parameters carefully
4.  Simulate transaction (Tenderly, Hardhat fork)
5.  Confirm with at least 1 other signer
6.  Document rationale

  **Never blindly sign transactions!**

### Regular Security Audits

**Quarterly Checklist**:
- [ ] Review all signers (active and accessible?)
- [ ] Test signing process (drill)
- [ ] Audit Safe transaction history
- [ ] Update emergency procedures
- [ ] Verify backup/recovery process
- [ ] Check for Safe contract upgrades
- [ ] Review signer security practices

---

## Emergency Procedures

### Scenario 1: Critical Vulnerability Discovered

**Severity**: HIGH - Immediate action required

**Steps**:
1. **Alert** all signers via emergency channel (5 minutes)
2. **Create** pause transaction in Safe (1 minute)
3. **Approve** transaction (get 5 signatures ASAP)
4. **Execute** pause transaction (1 minute)
5. **Announce** to community (public statement)
6. **Investigate** vulnerability with dev team
7. **Patch** contract or prepare fix
8. **Test** fix on testnet extensively
9. **Deploy** fix (if new contract needed)
10. **Unpause** or migrate users

**Target Time**: Pause within 30 minutes of discovery

### Scenario 2: Signer Compromise

**Severity**: MEDIUM - Urgent action required

**Steps**:
1. **Alert** other signers immediately
2. **Verify** compromise (not false alarm)
3. **Create** "Replace Owner" transaction
   - Remove compromised signer
   - Add replacement signer
4. **Get approvals** from non-compromised signers
5. **Execute** replacement transaction
6. **Investigate** how compromise occurred
7. **Document** incident for future prevention

**Target Time**: Remove within 24 hours

### Scenario 3: Loss of Signer Access

**Severity**: LOW - Routine action

**Context**: Signer lost private key, left team, etc.

**Steps**:
1. Verify remaining signers can meet threshold
   - 5-of-7: Still have 6 signers 
   - 4-of-5: Now have 4 signers   (urgent)
2. Plan replacement (no rush if threshold still achievable)
3. Remove lost signer
4. Add replacement signer
5. Update documentation

### Scenario 4: Rapid Parameter Adjustment Needed

**Severity**: MEDIUM - Fast action required

**Context**: Market conditions changed, exploit detected

**Steps**:
1. **Assess** situation (is it truly urgent?)
2. **Prepare** transaction with updated parameters
3. **Notify** all signers with clear rationale
4. **Fast-track** approvals (set 4-hour deadline)
5. **Execute** once threshold met
6. **Monitor** impact closely
7. **Document** decision and outcome

### Scenario 5: Safe Contract Upgrade

**Severity**: LOW - Planned action

**Context**: Gnosis Safe releases security update

**Steps**:
1. **Review** Safe upgrade announcement
2. **Test** upgrade on testnet Safe first
3. **Plan** migration timeline
4. **Create** upgrade transaction
5. **Get approvals** from all signers (no rush)
6. **Execute** upgrade
7. **Verify** all functionality intact
8. **Document** upgrade

### Emergency Contact Protocol

**24/7 Emergency Contacts**:

```
Lead Developer (Alice): +1-XXX-XXX-XXXX (Signal)
Smart Contract Engineer (Bob): +1-XXX-XXX-XXXX (Signal)
Security Auditor (Charlie): +1-XXX-XXX-XXXX (Signal)
Operations Lead (Diana): +1-XXX-XXX-XXXX (Signal)
Community Rep (Eve): +1-XXX-XXX-XXXX (Signal)
```

**Emergency Channels**:
- Signal Group: "BofhContract Emergency"
- Telegram: @BofhContractEmergency (backup)
- Email: emergency@bofhcontract.io (backup)

**Response Time Expectations**:
- **Critical (pause needed)**: 15 minutes
- **High (security issue)**: 2 hours
- **Medium (parameter change)**: 12 hours
- **Low (routine)**: 48 hours

---

## Appendix A: Gnosis Safe UI Walkthrough

### Dashboard Overview

```
                                                    
 BofhContract Mainnet Multisig                      
 0xYourSafe...                                      
                                                    $
 Assets      Transactions  Address Book  Apps   
                                                    $
                                                    
 Balance: 0.5 BNB ($150.00)                         
                                                    
 [+ New Transaction]                                
                                                    
 Recent Transactions:                               
  Updated Risk Parameters (5/7 approved)          
 ó Configure MEV Protection (3/7 approved)         
  Transferred Ownership (7/7 approved)            
                                                    
                                                    
```

### Creating a Transaction

```
                                                    
 New Transaction                                    
                                                    $
                                                    
 Transaction Type:                                  
 ¿ Send Funds                                       
 ¾ Contract Interaction    <-- SELECT THIS         
 ¾ Transaction Builder (Batch)                      
                                                    
 Contract Address:                                  
 [0xBofhContractAddress________]                    
                                                    
 ABI:                                               
 [ Load from BSCScan ]  [ Paste ABI ]               
                                                    
 Function:                                          
 [updateRiskParams ¼]                               
                                                    
 Parameters:                                        
 maxTradeVolume: [2000000000________]               
 minPoolLiquidity: [200000000________]              
 maxPriceImpact: [15________]                       
 sandwichProtectionBips: [75________]               
                                                    
 [ Simulate ]  [ Create Transaction ]               
                                                    
                                                    
```

### Approving a Transaction

```
                                                    
 Transaction #42: Update Risk Parameters            
                                                    $
 Status: 3 of 7 confirmations                       
                                                    
 Created by: Alice (0xAlice...)                     
 Created at: 2025-11-11 10:30 UTC                   
                                                    
 Details:                                           
 To: 0xBofhContractAddress                          
 Function: updateRiskParams                         
 Parameters:                                        
   - maxTradeVolume: 2000000000                     
   - minPoolLiquidity: 200000000                    
   - maxPriceImpact: 15                             
   - sandwichProtectionBips: 75                     
                                                    
 Confirmations:                                     
  Alice    (Proposer)                             
  Bob      (Approved 2h ago)                      
  Charlie  (Approved 1h ago)                      
 ó Diana    (Pending)                              
 ó Eve      (Pending)                              
 ó Frank    (Pending)                              
 ó Grace    (Pending)                              
                                                    
 [ Approve ]  [ Reject ]  [ Simulate ]              
                                                    
                                                    
```

---

## Appendix B: Troubleshooting

### Issue: Can't Connect Wallet to Safe

**Symptoms**: "Connect Wallet" button not working

**Solutions**:
1. Check you're on correct network (BSC, not Ethereum)
2. Clear browser cache and cookies
3. Try different browser (Chrome, Firefox, Brave)
4. Disable conflicting browser extensions
5. Update wallet extension to latest version
6. Try WalletConnect instead of direct connection

### Issue: Transaction Stuck at X of Y Signatures

**Symptoms**: Can't get enough signers to approve

**Solutions**:
1. Verify all signers have been notified
2. Check Safe transaction queue (signers may not see notification)
3. Share direct link to transaction
4. Verify signers are using correct wallets
5. Check if transaction is still valid (not expired)
6. If truly stuck, create new transaction and reject old one

### Issue: Gnosis Safe Gas Estimation Failed

**Symptoms**: "Gas estimation failed" error

**Solutions**:
1. Check contract function exists and is public
2. Verify you're calling correct function signature
3. Ensure Safe has BNB for gas
4. Try manually setting gas limit
5. Test function call on Hardhat fork first
6. Check if contract is paused (can't call functions)

### Issue: Can't Remove Signer

**Symptoms**: Remove owner transaction fails

**Solutions**:
1. Ensure removing signer doesn't break threshold
   - Example: 5-of-7 removing 1 = 5-of-6 (still valid )
   - Example: 4-of-5 removing 1 = 4-of-4 (invalid L)
2. If threshold breaks, lower threshold first, then remove
3. Or add new signer before removing old one

### Issue: Safe Contract Not Verified on BSCScan

**Symptoms**: Can't interact with Safe on BSCScan

**Solutions**:
1. This is normal - Safe uses proxy pattern
2. Use Gnosis Safe UI instead of BSCScan
3. Or get Safe implementation ABI from Etherscan

### Issue: Lost Threshold Number of Keys

**Severity**: CRITICAL - Safe is bricked

**Prevention**:
- Always use threshold < 70% (5-of-7, not 6-of-7)
- Document all signer private keys securely
- Test recovery process regularly

**Recovery** (if truly lost):
- Deploy new contract
- Pause old contract (if possible)
- Migrate users to new contract
- This is why we don't use 6-of-7 or higher!

---

## Appendix C: Script Reference

### Check Current Owner

```javascript
// check-owner.js
const { ethers } = require("hardhat");

async function main() {
  const bofhAddress = process.env.BOFH_CONTRACT_ADDRESS;
  const bofh = await ethers.getContractAt("BofhContractV2", bofhAddress);

  const owner = await bofh.admin();
  console.log("Current Owner:", owner);

  // Check if it's a multi-sig (has code)
  const code = await ethers.provider.getCode(owner);
  if (code === "0x") {
    console.log("   Owner is EOA (not multi-sig)");
  } else {
    console.log(" Owner is contract (likely multi-sig)");
    console.log("Code length:", code.length);
  }
}

main();
```

### Simulate Gnosis Safe Transaction

```javascript
// simulate-safe-tx.js
const { ethers } = require("hardhat");

async function main() {
  const safeAddress = process.env.GNOSIS_SAFE_ADDRESS;
  const bofhAddress = process.env.BOFH_CONTRACT_ADDRESS;

  // Impersonate Safe (for testing)
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [safeAddress],
  });

  const safeSigner = await ethers.getSigner(safeAddress);
  const bofh = await ethers.getContractAt("BofhContractV2", bofhAddress);

  // Simulate transaction
  const tx = await bofh.connect(safeSigner).updateRiskParams(
    ethers.parseEther("2000"),
    ethers.parseEther("200"),
    15,
    75
  );

  console.log(" Simulation successful");
  console.log("Gas estimate:", tx.gasLimit.toString());
}

main();
```

---

## Document Version

**Version**: 1.0
**Last Updated**: 2025-11-11
**Next Review**: Before mainnet deployment

---

> Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

# Security Guide

## Wallet Security

### Seed Phrase (Most Important!)

Your 25-word seed phrase is the master key to your wallet. Anyone with this phrase can access all your funds.

**DO:**
- Write it down on paper immediately when displayed
- Store in a secure, offline location (safe, safety deposit box)
- Make multiple copies stored in different locations
- Verify you wrote it correctly before sending funds to wallet

**DON'T:**
- Save seed phrase in a text file on your computer
- Take a screenshot of your seed phrase
- Store in cloud services (Google Drive, iCloud, Dropbox)
- Share with anyone, ever
- Enter on any website

### Wallet Files

Wallet files (`.keys` files in the `wallets/` directory) are encrypted with your password.

**Recommendations:**
- Use a strong, unique password (12+ characters)
- Back up wallet files to encrypted external storage
- Never email wallet files
- Delete wallet files securely when no longer needed

### Password Best Practices

If you set a password for your wallet:
- Use a password manager
- Don't reuse passwords from other sites
- Include uppercase, lowercase, numbers, and symbols
- Minimum 12 characters recommended

## Network Security

### Local-Only Operation

By default, COCAINE runs in offline mode for solo mining. This means:
- No connections to external nodes
- No peer-to-peer networking
- Your blockchain is completely local

### RPC Security

The daemon RPC binds to `0.0.0.0:19081` to allow local dashboard access.

**For additional security:**
- Use a firewall to block external access to ports 19081, 19083, 8080
- Only expose these ports on trusted networks
- Consider using `--rpc-bind-ip 127.0.0.1` for localhost-only access

### Firewall Rules (Optional)

macOS:
```bash
# Block external access to daemon
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/cocained
```

Linux (ufw):
```bash
# Allow local only
sudo ufw deny 19081
sudo ufw deny 19083
sudo ufw deny 8080
```

## File Permissions

Ensure proper permissions on sensitive files:

```bash
# Wallet files should only be readable by owner
chmod 600 wallets/*.keys

# Daemon and wallet binaries
chmod 755 bin/*
```

## Operational Security

### Mining Considerations

- Mining generates heat and uses electricity
- Monitor system temperatures
- Use appropriate cooling
- Be aware of electricity costs

### Privacy

- Wallet addresses are pseudonymous, not anonymous
- Transaction amounts are private (RingCT)
- Don't share your wallet address publicly if you want privacy
- Each transaction uses ring signatures for plausible deniability

## Recovery Procedures

### Lost Password

If you forget your wallet password but have your seed phrase:
1. Use `./cocaine.sh wallet` to open CLI
2. Create new wallet with seed recovery
3. All funds will be accessible

### Lost Wallet Files

If you lose your wallet files but have your seed phrase:
1. Start the dashboard
2. Click "Restore from Seed"
3. Enter your 25-word seed phrase
4. Wallet will be restored

### Lost Seed Phrase

If you lose your seed phrase but have wallet files + password:
- You can still access funds
- IMMEDIATELY send all funds to a new wallet with a saved seed phrase
- This is your last chance to recover

### Lost Everything

If you lose both seed phrase AND wallet files:
- Funds are permanently lost
- There is no recovery mechanism
- This is by design for privacy

## Incident Response

### If You Suspect Compromise

1. Create new wallet immediately
2. Transfer all funds to new wallet
3. Never use compromised wallet again
4. Investigate how compromise occurred
5. Secure your system

### Signs of Compromise

- Unexpected balance changes
- Wallet files accessed without your knowledge
- Unauthorized outgoing transactions
- Seed phrase discovered in unexpected locations

## Updates

- Always verify downloads from official sources
- Check file hashes when available
- Don't trust unofficial builds
- Keep your system and dependencies updated

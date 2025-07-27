#!/bin/bash
# Stellar Horizon Disk Setup Script for Linux VM
# This script prepares the additional disks for optimal Horizon performance

set -e

echo "🚀 Setting up disks for Stellar Horizon..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Create mount points
echo "📁 Creating mount points..."
mkdir -p /data/horizon
mkdir -p /data/postgres
mkdir -p /data/backups

# Setup the 32TB disk (sdc) for Horizon state data
echo "💾 Setting up 32TB disk (sdc) for Horizon state..."
# Check if sdc exists and is not mounted
if lsblk | grep -q "sdc"; then
    # Create filesystem if not exists
    if ! blkid /dev/sdc; then
        echo "Creating ext4 filesystem on /dev/sdc..."
        mkfs.ext4 -F /dev/sdc
    fi
    
    # Mount the disk
    echo "Mounting /dev/sdc to /data/horizon..."
    mount /dev/sdc /data/horizon
    
    # Add to fstab for persistent mounting
    UUID=$(blkid -s UUID -o value /dev/sdc)
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /data/horizon ext4 defaults,noatime 0 2" >> /etc/fstab
    fi
else
    echo "❌ /dev/sdc not found!"
    exit 1
fi

# Setup the 17.6TB disk (sdd) for PostgreSQL data
echo "🗄️ Setting up 17.6TB disk (sdd) for PostgreSQL..."
if lsblk | grep -q "sdd"; then
    # Create filesystem if not exists
    if ! blkid /dev/sdd; then
        echo "Creating ext4 filesystem on /dev/sdd..."
        mkfs.ext4 -F /dev/sdd
    fi
    
    # Mount the disk
    echo "Mounting /dev/sdd to /data/postgres..."
    mount /dev/sdd /data/postgres
    
    # Add to fstab for persistent mounting
    UUID=$(blkid -s UUID -o value /dev/sdd)
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /data/postgres ext4 defaults,noatime 0 2" >> /etc/fstab
    fi
else
    echo "❌ /dev/sdd not found!"
    exit 1
fi

# Set permissions for Docker
echo "🔐 Setting permissions..."
chmod 755 /data/horizon /data/postgres /data/backups
chown -R 999:999 /data/postgres  # PostgreSQL user in Docker

# Create backup directory on the PostgreSQL disk
mkdir -p /data/postgres/backups
mkdir -p /data/backups

# Optimize filesystem for database workloads
echo "⚡ Optimizing filesystem settings..."
# Add noatime mount option for better performance (already in fstab)
mount -o remount,noatime /data/horizon
mount -o remount,noatime /data/postgres

echo "✅ Disk setup completed!"
echo ""
echo "📊 Current disk status:"
df -h /data/horizon /data/postgres

echo ""
echo "🎯 Next steps:"
echo "1. Copy and configure your .env file"
echo "2. Update docker-compose.yml to use the new paths"
echo "3. Run 'make init && make up' to start Horizon" 
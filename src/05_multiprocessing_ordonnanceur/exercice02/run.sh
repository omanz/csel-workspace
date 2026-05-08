#!/bin/sh

# Monter le sous-système mémoire
mount -t tmpfs none /sys/fs/cgroup
mkdir /sys/fs/cgroup/memory
mount -t cgroup -o memory memory /sys/fs/cgroup/memory

# Créer un groupe
mkdir /sys/fs/cgroup/memory/mem

# Ajouter le shell courant au cgroup
echo $$ > /sys/fs/cgroup/memory/mem/tasks

# Limiter la memoire 
echo 20M > /sys/fs/cgroup/memory/mem/memory.limit_in_bytes

# Lancer le programme
./memtest
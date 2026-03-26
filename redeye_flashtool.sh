#!/bin/bash

# ==================================================
#    RedEyE  UNIVERSAL SMART FLASHER & EXTRACTOR
#    Version: 4.1 (Termux Safe Edition)
#    Developer:  Himel Majumdar Pronob
# ==================================================

# ================= Colors =================
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================= Banner =================
banner() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}          RedEyE UNIVERSAL SMART FLASHER          ${NC}"
    echo -e "${CYAN}         (Full Auto Flash & OFP Extractor)       ${NC}"
    echo -e "${CYAN}==================================================${NC}"
}

# ================= Dependency Check =================
check_dependencies() {
    if [ -n "$PREFIX" ]; then
        termux-setup-storage &> /dev/null
    fi
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}[!] Installing Python...${NC}"
        pkg install python -y
    fi
    if ! command -v fastboot &> /dev/null; then
        echo -e "${YELLOW}[!] Installing Fastboot...${NC}"
        pkg install android-tools -y
    fi
    pip install --upgrade pip &> /dev/null
    pip install pycryptodome requests &> /dev/null
}

# ================= OFP Extractor =================
extract_ofp() {
    echo -e "\n${YELLOW}[*] Preparing OFP Extractor...${NC}"
    if [ ! -f "ofp_decrypt.py" ]; then
        echo -e "${CYAN}[*] Downloading Decryption Engine...${NC}"
        curl -L -s -o ofp_decrypt.py "https://raw.githubusercontent.com/bkerler/oppo_tools/master/ofp_mtk_decrypt.py"
    fi
    echo -en "${YELLOW}[?] Enter FULL PATH of your .ofp file: ${NC}"
    read OFP_FILE
    if [ ! -f "$OFP_FILE" ]; then
        echo -e "${RED}[❌] Error: OFP file not found!${NC}"
        read -p "Press Enter to return..."
        return
    fi
    mkdir -p out
    echo -e "${GREEN}[🚀] Extraction Started...${NC}"
    python3 ofp_decrypt.py "$OFP_FILE" out/
    echo -e "${GREEN}[✅] Done! Files extracted to 'out/' folder.${NC}"
    read -p "Press Enter to return to menu..."
}

# ================= Auto Flash =================
auto_flash() {
    echo -en "${YELLOW}[?] Enter folder path containing images (or extracted OFP folder): ${NC}"
    read IMG_PATH
    if [ ! -d "$IMG_PATH" ]; then
        echo -e "${RED}[❌] Error: Directory not found!${NC}"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "${CYAN}[*] Waiting for device in fastboot mode...${NC}"
    while true; do
        DEVICE_SERIAL=$(fastboot devices | awk '{print $1}')
        if [ -n "$DEVICE_SERIAL" ]; then
            echo -e "${GREEN}[✅] Device Detected! Serial: $DEVICE_SERIAL${NC}"
            PRODUCT_NAME=$(fastboot getvar product 2>&1 | grep "product:" | awk '{print $2}')
            echo -e "${BLUE}[ℹ️] Target Device Product: ${PRODUCT_NAME:-Unknown}${NC}"
            break
        fi
        sleep 1
    done

    shopt -s nullglob
    FILES=( "$IMG_PATH"/*.img "$IMG_PATH"/*.bin )
    if [ ${#FILES[@]} -eq 0 ]; then
        echo -e "${RED}[❌] No .img or .bin files found!${NC}"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "${YELLOW}[!] Auto-detected partitions:${NC}"
    declare -A PART_MAP
    for f in "${FILES[@]}"; do
        PART_NAME=$(basename "$f" | cut -d'.' -f1)
        PART_MAP["$PART_NAME"]="$f"
        echo "  - $PART_NAME  --> $(basename "$f")"
    done

    echo -en "${YELLOW}[?] Start Auto Flashing ALL partitions? (y/n): ${NC}"
    read choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[!] Flashing cancelled.${NC}"
        return
    fi

    START_TIME=$SECONDS
    LOG_FILE="flash_log_$(date +%H%M%S).txt"

    for part in "${!PART_MAP[@]}"; do
        echo -e "${YELLOW}[⚡] Flashing $part ...${NC}"
        fastboot flash "$part" "${PART_MAP[$part]}" 2>&1 | tee -a "$LOG_FILE"
    done

    DURATION=$(( SECONDS - START_TIME ))
    echo -e "${GREEN}\nALL PARTITIONS FLASHED ✅ | Total Time: $((DURATION/60))m $((DURATION%60))s${NC}"

    # ===== Post-flash menu =====
    echo -e "\n${CYAN}[*] Flashing completed. Choose next action:${NC}"
    echo -e "${YELLOW}[1] Reboot Device${NC}"
    echo -e "${YELLOW}[2] Back to Main Menu${NC}"
    echo -en "${CYAN}[?] Select Option: ${NC}"
    read post_choice
    case $post_choice in
        1) echo -e "${CYAN}[*] Rebooting device...${NC}"; fastboot reboot ;;
        2) return ;;
        *) echo -e "${RED}Invalid choice, returning to menu.${NC}"; return ;;
    esac
    read -p "Press Enter to return to menu..."
}

# ================= Check Fastboot =================
check_fastboot() {
    echo -e "${CYAN}[*] Connected Fastboot Devices:${NC}"
    fastboot devices
    read -p "Press Enter to return to menu..."
}

# ================= Main Menu =================
while true; do
    banner
    echo -e "${YELLOW}[1] Auto Flash All Partitions (OFP / Extracted Folder)${NC}"
    echo -e "${YELLOW}[2] Extract .ofp Firmware (Oppo/Realme/OnePlus)${NC}"
    echo -e "${YELLOW}[3] Check Fastboot Devices${NC}"
    echo -e "${YELLOW}[4] Exit${NC}"
    echo -en "${CYAN}[?] Select Option: ${NC}"
    read main_choice

    check_dependencies

    case $main_choice in
        1) auto_flash ;;
        2) extract_ofp ;;
        3) check_fastboot ;;
        4) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid Option!${NC}" ; sleep 1 ;;
    esac
done

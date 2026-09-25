#!/bin/bash

# Enable UTF-8 support
export LANG=en_US.UTF-8

# Change to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Base directory for diagnostic reports
DIAG_ROOT="$SCRIPT_DIR/diagnostics"

# Set window title
echo -e "\033]0;Диагностика загрузки ГУ Haval M6\007"

# Function to print separator
print_separator() {
    echo
    echo -e "${YELLOW}*************************************************************************${NC}"
    echo
}

# Function to print welcome message
print_welcome() {
    clear
    echo "######################################################################################"
    echo "#                   Диагностика и анализ времени загрузки ГУ Haval M6                #"
    echo "#                                                                                    #"
    echo "#   Скрипт собирает системные логи, тайминги этапов старта (boot_progress),         #"
    echo "#   профиль Bootchart, состояние автозапуска и формирует сводный отчет.              #"
    echo "######################################################################################"
}

# Function to check device connectivity
check_devices() {
    echo -n "Ожидание подключения ГУ по ADB..."
    while true; do
        if adb devices 2>/dev/null | grep -q "device$"; then
            echo -e " ${GREEN}Подключено.${NC}"
            break
        else
            sleep 1
        fi
    done
}

# Ensure root access on device
ensure_root() {
    echo "Получение root прав через ADB..."
    adb root >/dev/null 2>&1 || true
    adb wait-for-device
}

# Function to create a timestamped session directory
create_session_dir() {
    local timestamp
    timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
    CURRENT_SESSION_DIR="$DIAG_ROOT/session_${timestamp}"
    mkdir -p "$CURRENT_SESSION_DIR"
    echo -e "Каталог сессии: ${CYAN}${CURRENT_SESSION_DIR}${NC}"
}

# 1. Collect static system info and state
collect_system_info() {
    local target_dir="$1"
    echo -e "\n${BLUE}==> Сбор системной информации...${NC}"
    
    echo "  -> Свойства системы (getprop)..."
    adb shell getprop > "$target_dir/getprop.txt" 2>/dev/null
    
    echo "  -> Дисковое пространство (df -h)..."
    adb shell df -h > "$target_dir/disk_usage.txt" 2>/dev/null
    
    echo "  -> Процессор и память (/proc/cpuinfo, /proc/meminfo)..."
    adb shell cat /proc/cpuinfo > "$target_dir/cpuinfo.txt" 2>/dev/null
    adb shell cat /proc/meminfo > "$target_dir/meminfo.txt" 2>/dev/null
    
    echo "  -> Список запущенных процессов (ps)..."
    adb shell ps -ef > "$target_dir/ps_ef.txt" 2>/dev/null || adb shell ps > "$target_dir/ps.txt" 2>/dev/null
    
    echo "  -> Список установленных пакетов (pm list packages -f)..."
    adb shell pm list packages -f > "$target_dir/packages_all.txt" 2>/dev/null
    adb shell pm list packages -s -f > "$target_dir/packages_system.txt" 2>/dev/null
    adb shell pm list packages -3 -f > "$target_dir/packages_third_party.txt" 2>/dev/null
    
    echo "  -> Автозапуск и зарегистрированные службы (dumpsys)..."
    adb shell dumpsys package queries > "$target_dir/package_queries.txt" 2>/dev/null
    adb shell dumpsys activity services > "$target_dir/activity_services.txt" 2>/dev/null
    adb shell dumpsys package | grep -B 2 -A 8 "android.intent.action.BOOT_COMPLETED" > "$target_dir/boot_completed_receivers.txt" 2>/dev/null
}

# 2. Collect runtime logs
collect_system_logs() {
    local target_dir="$1"
    echo -e "\n${BLUE}==> Выгрузка системных логов...${NC}"
    
    echo "  -> Лог ядра (dmesg)..."
    adb shell dmesg > "$target_dir/dmesg.log" 2>/dev/null
    
    echo "  -> Лог событий загрузки (logcat -b events)..."
    adb shell "logcat -b events -d" > "$target_dir/logcat_events.log" 2>/dev/null
    
    echo "  -> Полный системный журнал (logcat -b all -d)..."
    adb shell "logcat -b all -d" > "$target_dir/logcat_full.log" 2>/dev/null
    
    # Extract only boot milestones for quick analysis
    grep -E "boot_progress|boot_completed|sysui_|wm_boot" "$target_dir/logcat_events.log" > "$target_dir/boot_progress_raw.txt" 2>/dev/null || true
}

# 3. Analyze boot_progress milestones and produce summary
analyze_boot_metrics() {
    local session_dir="$1"
    local raw_file="$session_dir/boot_progress_raw.txt"
    local report_file="$session_dir/boot_analysis_summary.txt"
    
    if [ ! -s "$raw_file" ]; then
        # Try extracting from logcat_events.log directly if file empty
        if [ -f "$session_dir/logcat_events.log" ]; then
            grep -E "boot_progress" "$session_dir/logcat_events.log" > "$raw_file" 2>/dev/null || true
        fi
    fi
    
    echo -e "\n${BOLD}${CYAN}=========================================================================${NC}"
    echo -e "${BOLD}${CYAN}                    АНАЛИЗ ТАЙМИНГОВ ЗАГРУЗКИ (BOOT PROGRESS)            ${NC}"
    echo -e "${BOLD}${CYAN}=========================================================================${NC}\n"
    
    {
        echo "========================================================================="
        echo "                    АНАЛИЗ ТАЙМИНГОВ ЗАГРУЗКИ ГУ"
        echo " Дата отчета: $(date)"
        echo " Каталог сессии: $session_dir"
        echo "========================================================================="
        echo
    } > "$report_file"
    
    if [ ! -s "$raw_file" ]; then
        local msg="Метки boot_progress не найдены в логах. Возможно, буфер событий logcat перезаписан или ГУ не перезагружалось недавно."
        echo -e "${YELLOW}$msg${NC}"
        echo "$msg" >> "$report_file"
        return
    fi
    
    # Process milestones line by line
    local start_time=0
    local prev_time=0
    local prev_label="boot_start"
    
    printf "%-35s | %-12s | %-12s\n" "Этап загрузки" "Время (сек)" "Длительность" | tee -a "$report_file"
    printf -- "------------------------------------+--------------+-------------\n" | tee -a "$report_file"
    
    while IFS= read -r line; do
        # Extract tag and timestamp
        # Typical formats:
        # I/boot_progress_start( 1234): 4321
        # boot_progress_pms_system_scan_start: 12000
        local tag
        local time_ms
        
        tag=$(echo "$line" | grep -o -E 'boot_progress_[a-zA-Z0-9_]+')
        time_ms=$(echo "$line" | grep -o -E '[0-9]{4,10}' | tail -n 1)
        
        if [[ -n "$tag" && -n "$time_ms" ]]; then
            # Clean up tag label
            local friendly_tag="${tag#boot_progress_}"
            
            if [ "$start_time" -eq 0 ]; then
                start_time=$time_ms
                prev_time=$time_ms
            fi
            
            local total_sec
            local delta_sec
            total_sec=$(awk -v t="$time_ms" 'BEGIN { printf "%.2f", t / 1000 }')
            delta_ms=$((time_ms - prev_time))
            if [ $delta_ms -lt 0 ]; then delta_ms=0; fi
            delta_sec=$(awk -v d="$delta_ms" 'BEGIN { printf "%.2f", d / 1000 }')
            
            local color="${NC}"
            # Highlight stages taking longer than 7 seconds
            if [ "$delta_ms" -gt 7000 ]; then
                color="${RED}"
            elif [ "$delta_ms" -gt 3000 ]; then
                color="${YELLOW}"
            fi
            
            printf "${color}%-35s | %10s c | %10s c${NC}\n" "$friendly_tag" "$total_sec" "+$delta_sec"
            printf "%-35s | %10s c | %10s c\n" "$friendly_tag" "$total_sec" "+$delta_sec" >> "$report_file"
            
            prev_time=$time_ms
            prev_label=$friendly_tag
        fi
    done < "$raw_file"
    
    echo -e "\n${BOLD}Ключевые контрольные точки:${NC}" | tee -a "$report_file"
    echo "  • start                     - Старт виртуальной машины Android Framework (Zygote)" | tee -a "$report_file"
    echo "  • preload_start/end         - Предзагрузка системных классов и ресурсов" | tee -a "$report_file"
    echo "  • pms_start                 - Старт Package Manager Service" | tee -a "$report_file"
    echo "  • pms_system_scan_start/end - Сканирование /system/app и /system/priv-app" | tee -a "$report_file"
    echo "  • pms_data_scan_start       - Сканирование пользовательских приложений в /data/app" | tee -a "$report_file"
    echo "  • pms_scan_end              - Окончание проверки и верификации всех APK" | tee -a "$report_file"
    echo "  • ams_ready                 - Готовность Activity Manager Service к запуску окон" | tee -a "$report_file"
    echo "  • enable_screen             - Включение дисплея и готовность пользовательского интерфейса" | tee -a "$report_file"
    
    echo -e "\nСводный отчет сохранен в: ${CYAN}$report_file${NC}\n"
}

# 4. Profile entire boot using Bootchart
run_bootchart_profiling() {
    print_welcome
    print_separator
    
    check_devices
    ensure_root
    
    create_session_dir
    local session_dir="$CURRENT_SESSION_DIR"
    
    echo -e "\n${BOLD}${CYAN}==> Подготовка профилирования Bootchart на ГУ...${NC}"
    
    # Android bootchart looks for /data/bootchart/start or /data/bootchart-start
    # Value inside determines duration in seconds (120 sec is usually enough for car head units)
    adb shell "mkdir -p /data/bootchart" 2>/dev/null || true
    adb shell "echo 120 > /data/bootchart/start" 2>/dev/null || true
    adb shell "echo 120 > /data/bootchart-start" 2>/dev/null || true
    
    echo -e "${GREEN}Триггер Bootchart активирован на 120 секунд.${NC}"
    echo -e "${YELLOW}ГУ сейчас будет отправлено в перезагрузку для фиксации старта.${NC}"
    echo "Пожалуйста, не отключайте провод USB."
    echo -n "Нажмите Enter для начала перезагрузки и замера времени..."
    read -r
    
    local reboot_start_ts
    reboot_start_ts=$(date +%s)
    
    echo -e "\n${BLUE}Отправка команды перезагрузки (adb reboot)...${NC}"
    adb reboot
    
    echo "Ожидание отключения устройства..."
    sleep 3
    
    echo "Ожидание повторного подключения ГУ к ADB..."
    adb wait-for-device
    echo -e "${GREEN}Устройство снова на связи! Замеряем статус boot_completed...${NC}"
    
    # Wait until boot is completed (sys.boot_completed == 1)
    local boot_completed="0"
    local elapsed=0
    while [ "$boot_completed" != "1" ]; do
        boot_completed=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')
        elapsed=$(($(date +%s) - reboot_start_ts))
        echo -ne "  Время с момента перезагрузки: ${elapsed} сек...\r"
        if [ "$elapsed" -ge 180 ]; then
            echo -e "\n${YELLOW}Таймаут ожидания sys.boot_completed (180 сек). Продолжаем сбор данных.${NC}"
            break
        fi
        sleep 2
    done
    
    echo -e "\n${GREEN}Система полностью загрузилась за ~${elapsed} сек!${NC}"
    ensure_root
    
    echo "Ожидание завершения записи логов Bootchart (10 сек)..."
    sleep 10
    
    echo -e "\n${BLUE}Выгрузка файлов Bootchart на ноутбук...${NC}"
    mkdir -p "$session_dir/bootchart"
    adb pull /data/bootchart/ "$session_dir/bootchart/" 2>/dev/null || true
    
    # Cleanup bootchart triggers on device so it doesn't slow down normal operation
    echo "Очистка триггера Bootchart на ГУ..."
    adb shell "rm -f /data/bootchart/start /data/bootchart-start" 2>/dev/null || true
    adb shell "rm -rf /data/bootchart/*" 2>/dev/null || true
    
    # Collect logs and metrics from the fresh boot
    collect_system_info "$session_dir"
    collect_system_logs "$session_dir"
    
    # Analyze timings
    analyze_boot_metrics "$session_dir"
    
    print_separator
    echo -e "${GREEN}Профилирование успешно завершено!${NC}"
    echo "Все артефакты сохранены в: $session_dir"
    echo "Если на ноутбуке установлен python и pybootchartgui, диаграмму можно построить командой:"
    echo "  python3 -m pybootchartgui '$session_dir/bootchart/'"
    echo -n "Нажмите Enter для возврата в меню..."
    read -r
}

# 5. Quick snapshot without rebooting
run_quick_snapshot() {
    print_welcome
    print_separator
    
    check_devices
    ensure_root
    
    create_session_dir
    local session_dir="$CURRENT_SESSION_DIR"
    
    collect_system_info "$session_dir"
    collect_system_logs "$session_dir"
    analyze_boot_metrics "$session_dir"
    
    print_separator
    echo -e "${GREEN}Сбор данных текущего сеанса завершен!${NC}"
    echo "Файлы сохранены в: $session_dir"
    echo -n "Нажмите Enter для возврата в меню..."
    read -r
}

# 6. Analyze an existing session folder
run_analyze_existing() {
    print_welcome
    print_separator
    
    if [ ! -d "$DIAG_ROOT" ]; then
        echo -e "${YELLOW}Каталог диагностик пока не создан: $DIAG_ROOT${NC}"
        echo -n "Нажмите Enter для возврата..."
        read -r
        return
    fi
    
    echo "Доступные сессии:"
    local sessions=("$DIAG_ROOT"/*)
    local valid_sessions=()
    local idx=1
    
    for s in "${sessions[@]}"; do
        if [ -d "$s" ]; then
            valid_sessions+=("$s")
            echo "$idx. $(basename "$s")"
            ((idx++))
        fi
    done
    
    if [ ${#valid_sessions[@]} -eq 0 ]; then
        echo "Нет сохраненных сессий."
        echo -n "Нажмите Enter для возврата..."
        read -r
        return
    fi
    
    echo
    echo -n "Выберите номер сессии для повторного анализа (1-${#valid_sessions[@]}): "
    read -r sel
    
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#valid_sessions[@]}" ]; then
        local chosen="${valid_sessions[$((sel-1))]}"
        analyze_boot_metrics "$chosen"
    else
        echo -e "${RED}Неверный выбор.${NC}"
    fi
    
    echo -n "Нажмите Enter для возврата в меню..."
    read -r
}

# Interactive Menu
main_menu() {
    while true; do
        print_welcome
        print_separator
        
        echo "Выберите действие:"
        echo "1. Экспресс-диагностика текущего состояния (БЕЗ перезагрузки ГУ)"
        echo "2. Полное профилирование старта через Bootchart (С перезагрузкой ГУ)"
        echo "3. Повторный анализ ранее сохраненной сессии"
        echo "4. Ручной ввод команды ADB shell"
        echo "5. Выйти"
        echo
        echo -n "Введите ваш выбор (1-5): "
        read -r choice
        
        case $choice in
            1)
                run_quick_snapshot
                ;;
            2)
                run_bootchart_profiling
                ;;
            3)
                run_analyze_existing
                ;;
            4)
                print_separator
                echo "Интерактивная оболочка ADB shell. Введите 'exit' для выхода."
                adb shell
                ;;
            5)
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный номер, попробуйте снова.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check if adb is installed
if ! command -v adb &> /dev/null; then
    echo -e "${RED}Ошибка: ADB не найден в PATH. Установите Android SDK platform-tools.${NC}"
    exit 1
fi

# Handle CLI parameters if passed
case "$1" in
    --quick)
        check_devices
        ensure_root
        create_session_dir
        collect_system_info "$CURRENT_SESSION_DIR"
        collect_system_logs "$CURRENT_SESSION_DIR"
        analyze_boot_metrics "$CURRENT_SESSION_DIR"
        exit 0
        ;;
    --bootchart)
        run_bootchart_profiling
        exit 0
        ;;
    --analyze)
        if [ -n "$2" ] && [ -d "$2" ]; then
            analyze_boot_metrics "$2"
        else
            echo "Использование: $0 --analyze <путь_к_сессии>"
        fi
        exit 0
        ;;
    *)
        main_menu
        ;;
esac

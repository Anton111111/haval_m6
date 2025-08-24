#!/bin/bash

# Enable UTF-8 support
export LANG=en_US.UTF-8

# Change to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo $SCRIPT_DIR


# Set color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set title (for terminals that support it)
echo -e "\033]0;Расширение возможностей ГУ Haval M6\007"

# Path configurations
pathToAPK="$SCRIPT_DIR/apps/"
systemPath="system/app/"

# Application files
BackButton="BackButton.apk"
HUR="HUR_7.2.1.apk"
Dudu="DuduAutoUi1.001008.apk"
Autokit="Autokit.apk"
NavBar="nu_navbar-3_2_1.apk"

# Action constants
InstallAndroidAuto=1
InstallCarplay=2
DeleteApps=3
InstallHUR=4
RemoveHUR=5
InstallDudu=6
RemoveDudu=7
SerialNumberInfo=8
ManualCmd=9
Exit=10

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
    echo "#                       Добро пожаловать в установщик программ.                      #"
    echo "#   Автор скрипта не несет ответственности за выход из строя головного устройства.   #"
    echo "#                    Все действия выполняются на ваш страх и риск.                   #"
    echo "#                                                                                    #"
    echo "# Скрипт создан Александром (тг: @dahelmm)                                           #"
    echo "# Конвертирован в bash Anton (https://github.com/Anton111111, тг: @TheManFromSaturn) #"
    echo "# Группа в телеграмм https://t.me/haval_m6p                                          #"
    echo "#                                                                                    #"
    echo "######################################################################################"
}

# Function to check devices
check_devices() {
    while true; do
        if adb devices | grep -q "device$"; then
            echo -e "${GREEN}Подключение установлено.${NC}"
            break
        else
            echo -e "${RED}Устройства не обнаружены, проверьте подключение и нажмите любую клавишу для повторной проверки.${NC}"
            read -n 1 -s
        fi
    done
}

# Function to check file existence
check_file_existence() {
    local file="$1"
    while [ ! -f "$file" ]; do
        echo "Файл $file не найден, проверьте наличие файла и нажмите любую клавишу."
        read -n 1 -s
    done
}

# Function to push app
push_app() {
    local app="$1"
    local path="$2"
    echo "Произвожу копирование приложения $app в директорию $path..."
    adb push "$app" "$path"
    echo "Готово."
    print_separator
}

# Function to remove app
remove_app() {
    local app="$1"
    echo "Произвожу удаление приложения $app..."
    adb shell rm "$app"
    echo "Готово."
    print_separator
}

# Function for preparation
preparation_for_install() {
    echo "Вы включили режим ADB? (y/n)"
    read -n 1 -r answer
    echo
    
    if [[ $answer != [Yy] ]]; then
        echo
        echo "Проведем первоначальную настройку."
        echo "Заходим в настройки ГУ."
        read -n 1 -s
        echo "Поочередно 6 раз нажимаем \"Дисплей\"-\"Громкость\"-\"Общие\", откроется окно ввода пароля."
        read -n 1 -s
        echo "Вводим пароль (подключая проводную USB клавиатуру или используя Bluetooth-клавиатуру на телефоне): adayo2002"
        echo "Перед тем, как нажать \"ОК\", отключаем клавиатуру. Нажимаем \"ОК\"."
        read -n 1 -s
        echo "Попадаем в инженерное меню."
        echo "Включаем самый первый пункт \"ADB\"."
        read -n 1 -s
        echo "Втыкаем в USB на полке под ГУ кабель usb-a — usb-a"
        echo "Готово. Переходим к работе."
        read -n 1 -s
    fi
    print_separator
}

# Function to install Android Auto
install_android_auto() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Проверяю правильность путей до файлов приложений..."
    check_file_existence "${pathToAPK}${Dudu}"
    check_file_existence "${pathToAPK}${HUR}"
    echo "Файлы на месте, продолжаем."
    print_separator
    
    push_app "${pathToAPK}${Dudu}" "${systemPath}"
    push_app "${pathToAPK}${HUR}" "${systemPath}"
    adb reboot
    echo "Приложения установлены, ГУ ушло в перезагрузку. После перезагрузки нажмите любую клавишу и произведите настройку установленных приложений в соответствии со статьей на драйве."
    echo "https://www.drive2.ru/l/666836211133845140/"
    read -n 1 -s
    echo "Всё готово."
    read -n 1 -s
}

# Function to install Carplay
install_carplay() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Проверяю правильность путей до файлов приложений..."
    check_file_existence "${pathToAPK}${Dudu}"
    check_file_existence "${pathToAPK}${Autokit}"
    check_file_existence "${pathToAPK}${BackButton}"
    check_file_existence "${pathToAPK}${NavBar}"
    echo "Файлы на месте, продолжаем."
    print_separator
    
    push_app "${pathToAPK}${Dudu}" "${systemPath}"
    push_app "${pathToAPK}${Autokit}" "${systemPath}"
    push_app "${pathToAPK}${BackButton}" "${systemPath}"
    push_app "${pathToAPK}${NavBar}" "${systemPath}"
    
    adb reboot
    echo "Приложения установлены, ГУ ушло в перезагрузку. После перезагрузки нажмите любую клавишу и произведите настройку установленных приложений в соответствии со статьей на драйве."
    echo "https://www.drive2.ru/l/694348191084052856/"
    read -n 1 -s
    echo "Всё готово."
    read -n 1 -s
}

# Function to delete apps
delete_apps() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    # Directory for searching APK files
    local directory="${systemPath}"
    
    # Get list of APK files
    local count=0
    declare -a files
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            ((count++))
            files[$count]="$line"
            echo "$count. $line"
        fi
    done < <(adb shell ls "${directory}"*.apk 2>/dev/null)
    
    print_separator
    
    if [ $count -ne 0 ]; then
        echo "Введите номера файлов для удаления через запятую: "
        read -r numbers
        
        # Split the input by commas and process each number
        IFS=',' read -ra ADDR <<< "$numbers"
        for num in "${ADDR[@]}"; do
            # Remove spaces
            num=$(echo "$num" | tr -d ' ')
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$count" ]; then
                remove_app "${files[$num]}"
            fi
        done
        adb reboot
        echo "ГУ ушло в перезагрузку."
        read -n 1 -s
    else
        echo "Удалять нечего."
        read -n 1 -s
    fi
}

# Function to show serial number info
serial_number_info() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    echo "Будет отображён ваш серийный номер ГУ."
    read -n 1 -s
    adb get-serialno
    adb get-serialno >> ../iduser.txt
    echo "Номер ГУ можно посмотреть также в файле iduser.txt рядом со скриптом."
    read -n 1 -s
}

# Function to install HUR only
install_hur() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Проверяю правильность путей до файла HUR..."
    check_file_existence "${pathToAPK}${HUR}"
    echo "Файл на месте, продолжаем."
    print_separator
    
    push_app "${pathToAPK}${HUR}" "${systemPath}"
    adb reboot
    echo "HUR установлен, ГУ ушло в перезагрузку."
    read -n 1 -s
    echo "Всё готово."
    read -n 1 -s
}

# Function to remove HUR
remove_hur() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Удаляю HUR..."
    adb shell rm "${systemPath}${HUR}"
    echo "HUR удален."
    print_separator
    adb reboot
    echo "ГУ ушло в перезагрузку."
    read -n 1 -s
}

# Function to install DuDu only
install_dudu() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Проверяю правильность путей до файла DuDu..."
    check_file_existence "${pathToAPK}${Dudu}"
    echo "Файл на месте, продолжаем."
    print_separator
    
    push_app "${pathToAPK}${Dudu}" "${systemPath}"
    adb reboot
    echo "DuDu установлен, ГУ ушло в перезагрузку."
    read -n 1 -s
    echo "Всё готово."
    read -n 1 -s
}

# Function to remove DuDu
remove_dudu() {
    print_welcome
    print_separator
    
    preparation_for_install
    check_devices
    print_separator
    
    adb root
    adb disable-verity
    adb remount
    
    echo "Удаляю DuDu..."
    adb shell rm "${systemPath}${Dudu}"
    echo "DuDu удален."
    print_separator
    adb reboot
    echo "ГУ ушло в перезагрузку."
    read -n 1 -s
}

# Main menu function
choose_action() {
    while true; do
        print_welcome
        print_separator
        
        # Actions menu
        local actions=(
            "Установить Android Auto"
            "Установить Carplay"
            "Удаление установленных приложений"
            "Установить HUR"
            "Удалить HUR"
            "Установить DuDu"
            "Удалить DuDu"
            "Посмотреть серийный номер ГУ"
            "Ручной ввод команды в консоли"
            "Выйти из скрипта"
        )
        
        echo "Выберите действие:"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). ${actions[i]}"
        done
        
        echo -n "Введите ваш выбор (1-${#actions[@]}): "
        read -r actionChoice
        
        case $actionChoice in
            $InstallAndroidAuto)
                install_android_auto
                ;;
            $InstallCarplay)
                install_carplay
                ;;
            $DeleteApps)
                delete_apps
                ;;
            $InstallHUR)
                install_hur
                ;;
            $RemoveHUR)
                remove_hur
                ;;
            $InstallDudu)
                install_dudu
                ;;
            $RemoveDudu)
                remove_dudu
                ;;
            $SerialNumberInfo)
                serial_number_info
                ;;
            $ManualCmd)
                print_separator
                echo "Входим в ручной режим. Введите 'exit' для возврата в меню."
                bash
                ;;
            $Exit)
                exit 0
                ;;
            *)
                print_separator
                echo "Введен неверный номер, попробуйте снова."
                read -n 1 -s
                ;;
        esac
    done
}

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo -e "${RED}ADB не найден. Убедитесь, что Android SDK установлен и adb доступен в PATH.${NC}"
    exit 1
fi

# Start the main menu
choose_action

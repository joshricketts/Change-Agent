#!/bin/bash

# -----------------------------------------------------------------------------------
# *** STATIC VARIABLES ***
# -----------------------------------------------------------------------------------
version=1.0
logfile="/var/tmp/namechange.log"
starttime=$(date +%s)

title1="Update Username"
message1="To update your computer account's username please enter your **email address prefix** _(the part before @example.com)_ while **excluding** any special characters, capital letters, or spaces.  \n\n Enter your first and last name **including** a space between names in the **Full Name** field below:"

title2="Update Username"

# Setting variables to detect whether Installomator and SwiftDialog are currently installed or not.
installomator="/usr/local/Installomator/Installomator.sh"
dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"

dialogCMD1="$dialogApp --title \"$title1\" \
    --message \"$message1\" \
    --alignment center \
    --icon \"SF=person.line.dotted.person.fill\" \
    --textfield \"Email Prefix,prompt=No spaces, special characters, or capital letters\" \
    --textfield \"Full Name,prompt=First and last name with spaces\" \
    --commandfile \"$dialog_command_file\" \
    --moveable \
    --quitkey \"X\" \
    --infobuttontext \"Questions? Enter a ticket\" \
    --infobuttonaction \"https://enable.myportallogin.com\" \
    --button1text \"Continue...\" \
    "

# -----------------------------------------------------------------------------------
# *** STATIC FUNCTIONS ***
# -----------------------------------------------------------------------------------

# Clear out the SwiftDialog command file. Used at beginning of every run of the script.
function refresh_dialog_command_file(){
    rm "$dialog_command_file"
    touch "$dialog_command_file"
}

# Execute a SwiftDialog command.
function dialog_command(){
    echo $1
    echo $1  >> $dialog_command_file
}

# -----------------------------------------------------------------------------------
# *** INITIAL WINDOW TO CAPTURE INFO FROM USER ***
# -----------------------------------------------------------------------------------

refresh_dialog_command_file

/bin/echo $dialogCMD1
eval "$dialogCMD1" > "$logfile"
sleep 1

newUsername=$(grep "Email Prefix" "$logfile" | awk -F' : ' '{print $2}')
newFullName=$(grep "Full Name" "$logfile" | awk -F' : ' '{print $2}')

message2="New _Username_ will be **$newUsername**.  \n New _Full Name_ will be **$newFullName**.  \n\n Please save any data before clicking **Restart** below when ready.  \n\n Click **Cancel** if you need to re-run this program due to a typo.  \n\n If no action is taken the computer will update the name and restart in 5 minutes."

# -----------------------------------------------------------------------------------
# *** SECOND WINDOW AND ACCOUNT CHECK ***
# -----------------------------------------------------------------------------------

dialogCMD2="$dialogApp --title \"$title2\" \
    --message \"$message2\" \
    --alignment center \
    --icon \"SF=person.line.dotted.person.fill\" \
    --commandfile \"$dialog_command_file\" \
    --moveable \
    --quitkey \"X\" \
    --button1text \"Restart\" \
    --button2text \"Cancel\" \
    --timer 300 \
    --infobuttontext \"Questions? Enter support a ticket\" \
    --infobuttonaction \"https://enable.myportallogin.com\" \
    "

refresh_dialog_command_file

/bin/echo $dialogCMD2
eval "$dialogCMD2"; return_code=$?
sleep 1
echo $return_code


case $return_code in
    0)
    echo "User clicked 'Restart'"
    # Test to ensure logged in user is not being renamed
    readonly loggedInUser=$(ls -la /dev/console | cut -d " " -f 4)
    if [[ "${loggedInUser}" == "${oldUser}" ]]; then
        sudo launchctl bootout user/$(id -u %UserID%)
    fi

    # Verify valid username
    if [[ -z "${newUser}" ]]; then
        echo "New user name must not be empty!"
        exit 1
    fi

    # Test to ensure account update is needed
    if [[ "${oldUser}" == "${newUser}" ]]; then
        echo "No updates needed"
        exit 0
    fi

    # Query existing user accounts
    readonly existingUsers=($(dscl . -list /Users | grep -Ev "^_|com.*|root|nobody|daemon|\/" | cut -d, -f1 | sed 's|CN=||g'))

    # Ensure old user account is correct and account exists on system
    if [[ ! " ${existingUsers[@]} " =~ " ${oldUser} " ]]; then
        echo "${oldUser} account not present on system to update"
        exit 1
    fi

    # Ensure new user account is not already in use
    if [[ " ${existingUsers[@]} " =~ " ${newUser} " ]]; then
        echo "${newUser} account already present on system. Cannot add duplicate"
        exit 1
    fi

    # Query existing home folders
    readonly existingHomeFolders=($(ls /Users))

    # Ensure existing home folder is not in use
    if [[ " ${existingHomeFolders[@]} " =~ " ${newUser} " ]]; then
        echo "${newUser} home folder already in use on system. Cannot add duplicate"
        exit 1
    fi

    # Checks if user is logged in
    loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')

    # Logs out user if they are logged in
    timeoutCounter='0'
    while [[ "${loginCheck}" ]]; do
        echo "${oldUser} account logged in. Logging user off to complete username update."
        sudo launchctl bootout gui/$(id -u ${oldUser})
        Sleep 5
        loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')
        timeoutCounter=$((${timeoutCounter} + 1))
        if [[ ${timeoutCounter} -eq 4 ]]; then
            echo "Timeout unable to log out ${oldUser} account."
            exit 1
        fi
    done

    # Captures current "RealName" this is the displayName
    fullRealName=$(dscl . -read /Users/${oldUser} RealName)

    # Formats "RealName"
    readonly origRealName=$(echo ${fullRealName} | cut -d' ' -f2-)

    # Updates "RealName" to new username (Yes JCAgent will overwrite this after user/system association)
    sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RealName in dscl. - err=$?"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${origRealName}"
        exit 1
    fi

    # Captures current NFS home directory
    readonly origHomeDir=$(dscl . -read "/Users/${oldUser}" NFSHomeDirectory | awk '{print $2}' -)

    if [[ -z "${origHomeDir}" ]]; then
        echo "Cannot obtain the original home directory name, is the oldUserName correct?"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates NFS home directory
    sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory pointer, aborting further changes! - err=$?"
        echo "Reverting Home Directory changes"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates name of home directory to new username
    mv "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory in /Users"
        echo "Reverting Home Directory changes"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Actual username change
    sudo dscl . -change "/Users/${oldUser}" RecordName "${oldUser}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RecordName in dscl - the user should still be able to login, but with user name ${oldUser}"
        echo "Reverting username change"
        sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
        echo "Reverting Home Directory changes"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Links old home directory to new. Fixes dock mapping issue
    ln -s "/Users/${newUser}" "${origHomeDir}"

    sudo scutil --set ComputerName "$newFullName"
    sudo scutil --set LocalHostName "$newFullName"
    sudo scutil --set HostName "$newFullName"

    sudo shutdown -r now
    ;;

    2)
    echo "User canceled. Exiting"
    exit 2
    ;;

    4)
    echo "Timer expired."

# Test to ensure logged in user is not being renamed
    readonly loggedInUser=$(ls -la /dev/console | cut -d " " -f 4)
    if [[ "${loggedInUser}" == "${oldUser}" ]]; then
        sudo launchctl bootout user/$(id -u %UserID%)
    fi

    # Verify valid username
    if [[ -z "${newUser}" ]]; then
        echo "New user name must not be empty!"
        exit 1
    fi

    # Test to ensure account update is needed
    if [[ "${oldUser}" == "${newUser}" ]]; then
        echo "No updates needed"
        exit 0
    fi

    # Query existing user accounts
    readonly existingUsers=($(dscl . -list /Users | grep -Ev "^_|com.*|root|nobody|daemon|\/" | cut -d, -f1 | sed 's|CN=||g'))

    # Ensure old user account is correct and account exists on system
    if [[ ! " ${existingUsers[@]} " =~ " ${oldUser} " ]]; then
        echo "${oldUser} account not present on system to update"
        exit 1
    fi

    # Ensure new user account is not already in use
    if [[ " ${existingUsers[@]} " =~ " ${newUser} " ]]; then
        echo "${newUser} account already present on system. Cannot add duplicate"
        exit 1
    fi

    # Query existing home folders
    readonly existingHomeFolders=($(ls /Users))

    # Ensure existing home folder is not in use
    if [[ " ${existingHomeFolders[@]} " =~ " ${newUser} " ]]; then
        echo "${newUser} home folder already in use on system. Cannot add duplicate"
        exit 1
    fi

    # Checks if user is logged in
    loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')

    # Logs out user if they are logged in
    timeoutCounter='0'
    while [[ "${loginCheck}" ]]; do
        echo "${oldUser} account logged in. Logging user off to complete username update."
        sudo launchctl bootout gui/$(id -u ${oldUser})
        Sleep 5
        loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')
        timeoutCounter=$((${timeoutCounter} + 1))
        if [[ ${timeoutCounter} -eq 4 ]]; then
            echo "Timeout unable to log out ${oldUser} account."
            exit 1
        fi
    done

    # Captures current "RealName" this is the displayName
    fullRealName=$(dscl . -read /Users/${oldUser} RealName)

    # Formats "RealName"
    readonly origRealName=$(echo ${fullRealName} | cut -d' ' -f2-)

    # Updates "RealName" to new username (Yes JCAgent will overwrite this after user/system association)
    sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RealName in dscl. - err=$?"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${origRealName}"
        exit 1
    fi

    # Captures current NFS home directory
    readonly origHomeDir=$(dscl . -read "/Users/${oldUser}" NFSHomeDirectory | awk '{print $2}' -)

    if [[ -z "${origHomeDir}" ]]; then
        echo "Cannot obtain the original home directory name, is the oldUserName correct?"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates NFS home directory
    sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory pointer, aborting further changes! - err=$?"
        echo "Reverting Home Directory changes"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates name of home directory to new username
    mv "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory in /Users"
        echo "Reverting Home Directory changes"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Actual username change
    sudo dscl . -change "/Users/${oldUser}" RecordName "${oldUser}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RecordName in dscl - the user should still be able to login, but with user name ${oldUser}"
        echo "Reverting username change"
        sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
        echo "Reverting Home Directory changes"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Links old home directory to new. Fixes dock mapping issue
    ln -s "/Users/${newUser}" "${origHomeDir}"

    sudo scutil --set ComputerName "$newFullName"
    sudo scutil --set LocalHostName "$newFullName"
    sudo scutil --set HostName "$newFullName"

    sudo shutdown -r now
    ;;

    10)
    echo "User quit window."
    exit 10
    ;;

    *)
    echo "Error code 1"
    exit 1
    ;;
esac

exit
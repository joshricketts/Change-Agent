#!/bin/bash

# -----------------------------------------------------------------------------------
# *** STATIC VARIABLES ***
# -----------------------------------------------------------------------------------
version=1.0
date=$(date '+%m/%d/%Y')
logfile="/var/tmp/namechange.log"

token="YourAITtoken"
uname="admin_email@address.com"
pword="Admin-P4ssw0rd"
base64=$(echo "$uname":"$pword" | base64)

json="/var/tmp/userslist.json"
prettyjson="/var/tmp/prettyuserslist.json"
userinfo1="/var/tmp/user1.json"
userinfo2="/var/tmp/user2.json"

title1="Update your name for your laptop"
message1="To change your name in your computer please enter the following details in the fields below:  \n\n**New Name**  \n**New Email Address**  \n**Prior Email Address**  \n\nClick **Cancel** to stop this process."

title2="Updating Name on Server"
message2="Please wait while we pull your information..."

title3="Update Name Locally"
message3="To complete this process you must click **Restart** below.  \n\n_Please save all of your work now._  \n\nIf no action is taken this process will automatically continue in 5 minutes."

server_success="This computer name change script ran successfully on $date."

# Setting variables to detect whether Installomator and SwiftDialog are currently installed or not.
installomator="/usr/local/Installomator/Installomator.sh"
dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"

dialogCMD1="$dialogApp --title \"$title1\" \
    --message \"$message1\" \
    --alignment \"center\" \
    --icon \"SF=person.2.fill\" \
    --textfield \"New Name,prompt=Enter first name and last name separated by space\" \
    --textfield \"New Email Address,prompt=Enter email address\" \
    --textfield \"Prior Email Address,prompt=Enter email address\" \
    --commandfile \"$dialog_command_file\" \
    --moveable \
    --infobuttontext \"Questions? Enter a ticket\" \
    --infobuttonaction \"https://sbs.myportallogin.com\" \
    --button1text \"Continue...\" \
    --button2text \"Cancel\" \
    "

dialogCMD2="$dialogApp --title \"$title2\" \
    --message \"$message2\" \
    --alignment \"center\" \
    --icon \"SF=person.2.fill\" \
    --progress \"7\" \
    --commandfile \"$dialog_command_file\" \
    --moveable \
    --infobuttontext \"Questions? Enter a ticket\" \
    --infobuttonaction \"https://sbs.myportallogin.com\" \
    --button1text \"Close\" \
    --button1disabled \
    "

dialogCMD3="$dialogApp --title \"$title3\" \
    --message \"$message3\" \
    --alignment \"center\" \
    --icon \"SF=person.2.fill\" \
    --commandfile \"$dialog_command_file\" \
    --moveable \
    --small \
    --timer 300 \
    --infobuttontext \"Questions? Enter a ticket\" \
    --infobuttonaction \"https://sbs.myportallogin.com\" \
    --button1text \"Restart\" \
    "

# -----------------------------------------------------------------------------------
# *** STATIC FUNCTIONS ***
# -----------------------------------------------------------------------------------

# Clear out the SwiftDialog command file. Used at beginning of every run of the script.
function refresh_dialog_command_file(){
    rm "$dialog_command_file"
    touch "$dialog_command_file"
}

function refresh_user_info_logs(){
    rm "$logfile"
    touch "$logfile"
    rm "$userinfo1"
    touch "$userinfo1"
    rm "$userinfo2"
    touch "$userinfo2"
}


# Execute a SwiftDialog command.
function dialog_command(){
    echo $1
    echo $1  >> $dialog_command_file
}

# Window to show on success
function finalize(){
    final="success"
    touch "$logfile"
    echo "$server_success" > "$logfile"
    dialog_command "message: To complete the process you must restart your computer.  \n\nYou will be prompted to restart in a few seconds.  \n\nPlease make sure you have all your worked saved prior to restarting."
    dialog_command "progresstext: User info updated in Mosyle server!"
    dialog_command "progress: complete"
    dialog_command "icon: SF=person.fill.checkmark,color=green"
    dialog_command "button1: enable"
}

# Window to show on error.
function finalizeError(){
    final="error"
    dialog_command "message: There was an error in writing your new info to the Mosyle server."
    dialog_command "progresstext: Error occurred writing data to Mosyle server!"
    dialog_command "progress: complete"
    dialog_command "icon: SF=person.fill.questionmark,color=yellow"
    dialog_command "button1text: Close"
    dialog_command "button1: enable" 
    exit 0
}

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  dialogExpectedTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$dialogExpectedTeamID" = "$teamID" ] || [ "$dialogExpectedTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else 
      dialogAppleScript
      exitCode=1
      exit $exitCode
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
  else echo "Dialog already found. Proceeding..."
  fi
}

function ListUsersAPI(){
    cat <<EOF
    {
    "accessToken": "$token",
    "options": {
        "page": "$i",
        "specific_columns": [
            "type",
            "id",
            "account",
            "locations",
            "email",
            "name"
        ]
    }
}
EOF
}

# -----------------------------------------------------------------------------------
# *** VERIFY USER IS SIGNED IN & CHECK FOR DIALOG APP ***
# -----------------------------------------------------------------------------------

# Check that a user is logged in currently.
setupAssistantProcess=$(pgrep -l "Setup Assistant")
until [ "$setupAssistantProcess" = "" ]; do
    echo "$(date "+%a %h %d %H:%M:%S"): Setup Assistant Still Running. PID $setupAssistantProcess." 2>&1 | tee -a /var/tmp/deploy.log
    sleep 5
    timestamp=$(date +%s)
    if (( $starttime + 1800 < $timestamp )); then
        echo "Process timed out. No user logged in." 2>&1 | tee -a /var/tmp/deploy.log
        exit
    fi
    setupAssistantProcess=$(pgrep -l "Setup Assistant")
done
echo "$(date "+%a %h %d %H:%M:%S"): Out of Setup Assistant" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log

        finderProcess=$(pgrep -l "Finder")
until [ "$finderProcess" != "" ]; do
    echo "$(date "+%a %h %d %H:%M:%S"): Finder process not found. Assuming device is at login screen. PID $finderProcess" 2>&1 | tee -a /var/tmp/deploy.log
    sleep 5
    timestamp=$(date +%s)
    if (( $starttime + 1800 < $timestamp )); then
        echo "Process timed out. No user logged in." 2>&1 | tee -a /var/tmp/deploy.log
        exit
    fi
    finderProcess=$(pgrep -l "Finder")
done
echo "$(date "+%a %h %d %H:%M:%S"): Finder is running" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log

dialogCheck

# -----------------------------------------------------------------------------------
# *** INITIAL WINDOW TO CAPTURE INFO FROM USER ***
# -----------------------------------------------------------------------------------

refresh_dialog_command_file
refresh_user_info_logs

/bin/echo $dialogCMD1
eval "$dialogCMD1" > "$logfile"
return_code=$?
echo $return_code
sleep 0.1

oldEmail=$(grep "Prior Email Address" "$logfile" | awk -F' : ' '{print $2}')
newEmail=$(grep "New Email Address" "$logfile" | awk -F' : ' '{print $2}')
oldUser=$(grep "Prior Email Address" "$logfile" | awk -F' : ' '{print $2}' | awk -F'@' '{print $1}')
newUser=$(grep "New Email Address" "$logfile" | awk -F' : ' '{print $2}' | awk -F'@' '{print $1}')
newName=$(grep "New Name" "$logfile" | awk -F' : ' '{print $2}')

case $return_code in
0)
# -----------------------------------------------------------------------------------
# *** SECOND WINDOW AND ACCOUNT CHECK ***
# -----------------------------------------------------------------------------------

refresh_dialog_command_file

/bin/echo $dialogCMD2
eval "$dialogCMD2" &
sleep 0.1

# -----------------------------------------------------------------------------------
# STEP 0: INITIALIZE
# -----------------------------------------------------------------------------------

dialog_command "progress: 0"
dialog_command "progresstext: Initializing..."
sleep 2

# -----------------------------------------------------------------------------------
# STEP 1: PULL USER DATA FROM MOSYLE VIA API
# -----------------------------------------------------------------------------------

dialog_command "progress: 1"
dialog_command "progresstext: Pulling data from server..."

# Pull list of users from Mosyle
for i in {1..10}; do
curl -L -X POST 'https://managerapi.mosyle.com/v2//listusers' -H 'Content-Type: application/json' -H "Authorization: Basic $base64" --data-raw "$(ListUsersAPI)" >> "$json"
done
sleep 1

# -----------------------------------------------------------------------------------
# STEP 2: SEARCH THROUGH USER DATA TO FIND THE USER'S ACCOUNT BASED ON THEIR ENTERED INFORMATION
# -----------------------------------------------------------------------------------

dialog_command "progress: 2"
dialog_command "progresstext: Scanning for account information..."


# separate single line out into JSON that is scannable for the relevant info
echo `cat $json` | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: 'BEGIN{OFS=":"} {print $1,$2}' >> "$prettyjson"

grep -A2 -B2 "\"email\":\"$oldEmail\"" "$prettyjson" >> "$userinfo1"

type=$(grep "type" "$userinfo1" | awk -F':' '{print $2}' | cut -d '"' -f2)
location=$(grep "locations" "$userinfo1" | awk -F':' '{print $2}' | cut -d '"' -f2)
oldUser=$(grep "id" "$userinfo1" | awk -F':' '{print $2}' | cut -d '"' -f2)

echo "Old user is $oldUser."
echo "New user is $newUser."
echo "New email address is $newEmail"
echo "New name is $newName."
echo "Account type is $type."
echo "Location is $location."
sleep 1

function CreateNewUserAPI(){
    cat <<EOF
    {
   "accessToken": "$token",
    "elements": [
        {
            "operation": "save",
            "id": "$newUser",
            "name": "$newName",
            "type": "$type",
            "email": "$newEmail",
            "managed_appleid": "$newEmail",
            "locations": [
                {
                    "name": "$location"
                }
            ],
            "welcome_email": 0
        }
    ]
}
EOF
}

# -----------------------------------------------------------------------------------
# STEP 3: INFORM USER THAT DETAILS WERE FOUND
# -----------------------------------------------------------------------------------

dialog_command "progress: 3"
dialog_command "progresstext: Account details found..."
dialog_command "message: Prior account ID is **$oldUser**.  \n\nNew account ID is **$newUser**.  \n\nNew email address is **$newEmail**.  \n\nAccount type is **$type**.  \n\nLocation is **$location**."
sleep 1

# -----------------------------------------------------------------------------------
# STEP 4: USE MOSYLE API TO WRITE NEW 
# -----------------------------------------------------------------------------------

dialog_command "progress: 4"
dialog_command "progresstext: Updating account in Mosyle server..."

curl -L -X POST 'https://managerapi.mosyle.com/v2//users' -H 'Content-Type: application/json' -H "Authorization: Basic $base64" --data-raw "$(CreateNewUserAPI)"

sleep 1

# -----------------------------------------------------------------------------------
# STEP 5: PULL USER DATA AGAIN VIA MOSYLE API
# -----------------------------------------------------------------------------------

dialog_command "progress: 5"
dialog_command "progresstext: Checking for data in server..."



for i in {1..10}; do
curl -L -X POST 'https://managerapi.mosyle.com/v2//listusers' -H 'Content-Type: application/json' -H "Authorization: Basic $base64" --data-raw "$(ListUsersAPI)" >> "$json"
done
sleep 1

# -----------------------------------------------------------------------------------
# STEP 6: VERIFY NEW USER DATA HAS BEEN ADDED
# -----------------------------------------------------------------------------------

dialog_command "progress: 6"
dialog_command "progresstext: Verifying user data updated..."

# touch "$userinfo"

echo `cat $json` | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: 'BEGIN{OFS=":"} {print $1,$2}' >> "$prettyjson"

grep -A4 -B0 "\"id\":\"$newUser\"" "$prettyjson" >> "$userinfo2"

rm "$logfile"
rm "$json"
rm "$prettyjson"

newID_verification=$(grep "\"id\":\"$newUser\"" "$userinfo2" | awk -F':' '{print $2}' | cut -d '"' -f2)
sleep 1

# -----------------------------------------------------------------------------------
# STEP 7: IF NEW ACCOUNT IS FOUND THEN PROCEED WITH 
# -----------------------------------------------------------------------------------

if [[ "$newUser" == "$newID_verification" ]]; then
    finalize
else
    finalizeError
fi

sleep 7

sudo pkill "Dialog"

# -----------------------------------------------------------------------------------
# PERFORM ACTION BASED ON EXIT CODE OF THE DIALOG WINDOW
# -----------------------------------------------------------------------------------

if [[ "$final" == "success" ]]; then
    refresh_dialog_command_file

    /bin/echo $dialogCMD3
    eval "$dialogCMD3"; return_code=$?
    sleep 0.1
    echo $return_code 2>&1 | tee -a "$logfile"
fi

case $return_code in
    0)
    # Test to ensure logged in user is not being renamed
    readonly loggedInUser=$(ls -la /dev/console | cut -d " " -f 4)
    if [[ "${loggedInUser}" == "$oldUser" ]]; then
        echo "Old user currently logged in. Forcing logout to continue script." 2>&1 | tee -a "$logfile"
        sudo launchctl bootout user/$(id -u $loggedInUser) 2>&1 | tee -a "$logfile"
    fi

    # Verify valid username
    if [[ -z "$newUser" ]]; then
        echo "New user name must not be empty!" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Test to ensure account update is needed
    if [[ "$oldUser" == "$newUser" ]]; then
        echo "No updates needed" 2>&1 | tee -a "$logfile"
        exit 0
    fi

    # Query existing user accounts
    readonly existingUsers=($(dscl . -list /Users | grep -Ev "^_|com.*|root|nobody|daemon|\/" | cut -d, -f1 | sed 's|CN=||g'))

    # Ensure old user account is correct and account exists on system
    if [[ ! " ${existingUsers[@]} " =~ "$oldUser" ]]; then
        echo "$oldUser account not present on system to update" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Ensure new user account is not already in use
    if [[ " ${existingUsers[@]} " =~ "$newUser" ]]; then
        echo "${newUser} account already present on system. Cannot add duplicate" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Query existing home folders
    readonly existingHomeFolders=($(ls /Users))

    # Ensure existing home folder is not in use
    if [[ " ${existingHomeFolders[@]} " =~ "$newUser" ]]; then
        echo "${newUser} home folder already in use on system. Cannot add duplicate" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Checks if user is logged in
    loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')

    # Logs out user if they are logged in
    timeoutCounter='0'
    while [[ "${loginCheck}" ]]; do
        echo "${oldUser} account logged in. Logging user off to complete username update." 2>&1 | tee -a "$logfile"
        sudo launchctl bootout gui/$(id -u ${oldUser})
        Sleep 5
        loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')
        timeoutCounter=$((${timeoutCounter} + 1))
        if [[ ${timeoutCounter} -eq 4 ]]; then
            echo "Timeout unable to log out ${oldUser} account." 2>&1 | tee -a "$logfile"
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
        echo "Could not rename the user's RealName in dscl. - err=$?" 2>&1 | tee -a "$logfile"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${origRealName}"
        exit 1
    fi

    # Captures current NFS home directory
    readonly origHomeDir=$(dscl . -read "/Users/${oldUser}" NFSHomeDirectory | awk '{print $2}' -)

    if [[ -z "${origHomeDir}" ]]; then
        echo "Cannot obtain the original home directory name, is the oldUserName correct?" 2>&1 | tee -a "$logfile"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates NFS home directory
    sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory pointer, aborting further changes! - err=$?" 2>&1 | tee -a "$logfile"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates name of home directory to new username
    mv "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory in /Users" 2>&1 | tee -a "$logfile"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Actual username change
    sudo dscl . -change "/Users/${oldUser}" RecordName "${oldUser}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RecordName in dscl - the user should still be able to login, but with user name ${oldUser}" 2>&1 | tee -a "$logfile"
        echo "Reverting username change" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
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
    echo "User canceled" 2>&1 | tee -a "$logfile"
    exit 2
    ;;

    4)
    # Test to ensure logged in user is not being renamed
    readonly loggedInUser=$(ls -la /dev/console | cut -d " " -f 4)
    if [[ "${loggedInUser}" == "$oldUser" ]]; then
        echo "Old user currently logged in. Forcing logout to continue script." 2>&1 | tee -a "$logfile"
        sudo launchctl bootout user/$(id -u $loggedInUser) 2>&1 | tee -a "$logfile"
    fi

    # Verify valid username
    if [[ -z "$newUser" ]]; then
        echo "New user name must not be empty!" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Test to ensure account update is needed
    if [[ "$oldUser" == "$newUser" ]]; then
        echo "No updates needed" 2>&1 | tee -a "$logfile"
        exit 0
    fi

    # Query existing user accounts
    readonly existingUsers=($(dscl . -list /Users | grep -Ev "^_|com.*|root|nobody|daemon|\/" | cut -d, -f1 | sed 's|CN=||g'))

    # Ensure old user account is correct and account exists on system
    if [[ ! " ${existingUsers[@]} " =~ "$oldUser" ]]; then
        echo "$oldUser account not present on system to update" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Ensure new user account is not already in use
    if [[ " ${existingUsers[@]} " =~ "$newUser" ]]; then
        echo "${newUser} account already present on system. Cannot add duplicate" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Query existing home folders
    readonly existingHomeFolders=($(ls /Users))

    # Ensure existing home folder is not in use
    if [[ " ${existingHomeFolders[@]} " =~ "$newUser" ]]; then
        echo "${newUser} home folder already in use on system. Cannot add duplicate" 2>&1 | tee -a "$logfile"
        exit 1
    fi

    # Checks if user is logged in
    loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')

    # Logs out user if they are logged in
    timeoutCounter='0'
    while [[ "${loginCheck}" ]]; do
        echo "${oldUser} account logged in. Logging user off to complete username update." 2>&1 | tee -a "$logfile"
        sudo launchctl bootout gui/$(id -u ${oldUser})
        Sleep 5
        loginCheck=$(ps -Ajc | grep ${oldUser} | grep loginwindow | awk '{print $2}')
        timeoutCounter=$((${timeoutCounter} + 1))
        if [[ ${timeoutCounter} -eq 4 ]]; then
            echo "Timeout unable to log out ${oldUser} account." 2>&1 | tee -a "$logfile"
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
        echo "Could not rename the user's RealName in dscl. - err=$?" 2>&1 | tee -a "$logfile"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${origRealName}" "${origRealName}"
        exit 1
    fi

    # Captures current NFS home directory
    readonly origHomeDir=$(dscl . -read "/Users/${oldUser}" NFSHomeDirectory | awk '{print $2}' -)

    if [[ -z "${origHomeDir}" ]]; then
        echo "Cannot obtain the original home directory name, is the oldUserName correct?" 2>&1 | tee -a "$logfile"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates NFS home directory
    sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory pointer, aborting further changes! - err=$?" 2>&1 | tee -a "$logfile"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Updates name of home directory to new username
    mv "${origHomeDir}" "/Users/${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's home directory in /Users" 2>&1 | tee -a "$logfile"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RealName "${newUser}" "${origRealName}"
        exit 1
    fi

    # Actual username change
    sudo dscl . -change "/Users/${oldUser}" RecordName "${oldUser}" "${newUser}"

    if [[ $? -ne 0 ]]; then
        echo "Could not rename the user's RecordName in dscl - the user should still be able to login, but with user name ${oldUser}" 2>&1 | tee -a "$logfile"
        echo "Reverting username change" 2>&1 | tee -a "$logfile"
        sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
        echo "Reverting Home Directory changes" 2>&1 | tee -a "$logfile"
        mv "/Users/${newUser}" "${origHomeDir}"
        sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${origHomeDir}"
        echo "Reverting RealName changes" 2>&1 | tee -a "$logfile"
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
    echo "User figured out quit key." 2>&1 | tee -a "$logfile"
    exit 10
    ;;

    *)
    echo "Something else happened" 2>&1 | tee -a "$logfile"
    exit 1
    ;;
esac
;;

2)
echo "User canceled"
exit 2
;;

*)
echo "Something else happened"
exit $return_code
;;
esac

exit 

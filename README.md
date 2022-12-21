# Change-Agent

This tool is just a collection of scripts designed to get an end-user to update their account name/short name of their user account. 

Massive thanks to Bart Reardon's SwiftDialog which is the tool handling all of the pop-up windows and text gathering. Another thanks to TheJumpCloud for their RenameMacUserNameAndHomeDirectory.sh script which is what is handling the meat of the local username and home directory change. Links to both below:

**SwiftDialog by Bart Reardon: https://github.com/bartreardon/swiftDialog**
**RenameMacUserNameAndHomeDirectory.sh by TheJumpCloud: https://github.com/TheJumpCloud/support/blob/master/scripts/macos/RenameMacUserNameAndHomeDirectory.sh**

**RenameUser.sh** is a generic script that is meant to simply rename the user on the device.

**RenameUserMosyle.sh** will handle verifying user data in your Mosyle tenant via API calls to create a new user with the matching information, as well as handle the local username/home directory change. This may not be NEEDED in every case, but it does prevent any issues on devices running Mosyle Auth where the email address entered needs to match what's on file. 

# User-Interface

1. The user is presented with a window with textboxes asking for the relevant information

<img width="816" alt="Screenshot 2022-12-21 at 12 12 26 PM" src="https://user-images.githubusercontent.com/105330539/208980022-71fda8cf-3e77-4344-98b1-39b1a6c2cec0.png">


2. In the Mosyle version the user is presented with another window to inform them of the progress of checking user info, updating it, and verifying it was successfully updated. 

<img width="815" alt="Screenshot 2022-12-21 at 12 13 17 PM" src="https://user-images.githubusercontent.com/105330539/208980082-36686551-6730-4aaf-9e93-2c0c51dce9a4.png">


<img width="813" alt="Screenshot 2022-12-21 at 12 21 51 PM" src="https://user-images.githubusercontent.com/105330539/208980138-b0f7cef9-2fd3-4ace-a037-90cc985df060.png">

Success:
<img width="814" alt="Screenshot 2022-12-21 at 12 42 27 PM" src="https://user-images.githubusercontent.com/105330539/208980223-7824c02c-5c4b-4839-a49f-fe61d0b9e49c.png">

Error:
<img width="608" alt="Screenshot 2022-12-21 at 12 40 12 PM" src="https://user-images.githubusercontent.com/105330539/208980296-abd1959e-a0ac-4ac9-b6ff-4b9db6fc0581.png">


3. The user is presented with a second window informing them that they will need to restart to complete the process with a buffer timer to allow them time to save any work. 

<img width="608" alt="Screenshot 2022-12-21 at 12 40 12 PM" src="https://user-images.githubusercontent.com/105330539/208980354-ea5ae96a-b15a-4963-a559-141a919d55c1.png">




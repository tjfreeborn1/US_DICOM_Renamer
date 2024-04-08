# US_DICOM_Renamer

## Description
Ultrasound DICOM Renamer is a MATLAB-based graphical user interface that facilitates workflow improvements in organizing and renaming DICOM format ultrasound image files. It provides a platform to quickly visualize exported images, generate descriptive filenames using DICOM meta-data and optical character recognition applied to the image, and save renamed files organized by subject.

<img src="https://raw.githubusercontent.com/tjfreeborn1/US_DICOM_Renamer/main/img/GUI_Open.jpg" width="440">

## System Requirements
This application requires installation of MATLAB with the Computer Vision Toolbox and Image Processing Toolbox.  To use this application, download and run `US_DICOM_Renamer.mlapp`.  This will launch MATLAB (if not already running) and open the GUI for use.

## Functionalities
The functionalities that contribute to the process improvements for ultrasound image organization and renaming using this GUI are:

### Image Identification: 
The complete list of files to rename is generated from all files within the user-selected directory (and all subsequent sub-directories).  Files that are not DICOM in format/content are removed from further processing.   
 
### Filename Suggestion: 
Filenames are suggested using a combination of DICOM meta-data (participant ID) and text identified on the ultrasound image (typically placed by the operator with image context details).  The text is identified using optical character recognition (OCR) applied to the entire ultrasound image. Identified characters are used in a suggested filename for the image in the format **ParticipantID\OCRImageText**.

### Region of Interest:
The region of interest can be revised by the user to specify the exact area within the image with placed text.  This can be used to improve OCR performance by removing non-text imaging data from being processed.  After revising, this region is used for all subsequent images until revised again by the user or the GUI is restarted.

### Error-Checking: 
The application includes error checking to validate files are in DICOM format (and excluded otherwise), removes filename characters that could be unacceptable for operating systems (e.g. <>:"|?*!@\#\$\% \^{}\&()[]{}|), and confirms that the filename for the current image does not already exist in the target directory.  And in cases where it does, appends **_X** to make a unique name, where **X** is a natural number that increases by 1 until a new unique name is generated.

### Summary:
The application generates a summary text file (**summary.txt**) to log important actions during the renaming process with the GUI.  These actions include the start and stop time of the session and a list of renamed files (including original names).  This summary is to support evaluation of renaming activities in case there is an unexpected GUI error or process exception that causes the renaming session to end before completing all images. 

## Demonstrations
Below are examples of navigating and using the application to load an ultrasound directory, select a region of interest for filename generation, and renaming files.

### Loading Ultrasound Directory
Navigate to the highest-level directory that DICOM images are stored within.  After selecting, application will scan all sub-folders to identify DICOM images for renaming and open/display the first image to start the renaming process.

![DirectoryExample](https://raw.githubusercontent.com/tjfreeborn1/US_DICOM_Renamer/main/img/Example_US_DirOpen.gif)

### Selecting Region of Interest
The default region of interest that is scanned for words/characters to generate a suggested filename is shown in red after clicking the **Show ROI** box.  This area can be revised to a user-selected area as needed.

![RegionExample](https://raw.githubusercontent.com/tjfreeborn1/US_DICOM_Renamer/main/img/Example_US_ROI.gif)

### Revising Filename
Clicking **Rename** copies the current DICOM image to a new directory, which is organized by participant ID, with either application suggested filename (**OCR Image Name**) or user suggested filename (**New Image Name**).  The applicated suggested name is used by default with the user suggested name used only if additional characters are added to that text box.  After renaming, next image is loaded for review to continue the process.

![RevisingExample](https://raw.githubusercontent.com/tjfreeborn1/US_DICOM_Renamer/main/img/Example_US_Rename.gif)

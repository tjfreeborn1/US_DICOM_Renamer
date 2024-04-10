classdef US_DICOM_Renamer < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UltrasoundRenameToolUIFigure  matlab.ui.Figure
        ForwardButton                 matlab.ui.control.Button
        BackButton                    matlab.ui.control.Button
        ReviseROIButton               matlab.ui.control.Button
        ShowROICheckBox               matlab.ui.control.CheckBox
        OCRImageNameTextArea          matlab.ui.control.TextArea
        OCRImageNameLabel             matlab.ui.control.Label
        ImageNameTextArea             matlab.ui.control.TextArea
        ImageNameTextAreaLabel        matlab.ui.control.Label
        NewImageNameEditField         matlab.ui.control.EditField
        NewImageNameLabel             matlab.ui.control.Label
        ParticipantIDTextArea         matlab.ui.control.TextArea
        ParticipantIDTextAreaLabel    matlab.ui.control.Label
        CurrentImageTextArea          matlab.ui.control.TextArea
        CurrentImageTextAreaLabel     matlab.ui.control.Label
        TotalImagesTextArea           matlab.ui.control.TextArea
        TotalImagesTextAreaLabel      matlab.ui.control.Label
        RenameButton                  matlab.ui.control.Button
        SelectUltrasoundDirectoryButton  matlab.ui.control.Button
        ImageAxes                     matlab.ui.control.UIAxes
    end


    properties (Access = private)
        image_path; % Variable with path/folder containing ultrasound/DICOM images to rename
        US_Image; % Variable to current ultrasound/DICOM image being renamed
        info; % Variable to hold DICOM meta-data from opened ultrasound/DICOM image

        filelist; % Variable to setup list with all ultrasound/DICOM images to rename
        renameTracker = 1; % Variable to track how many images have been renamed from total set in fileList
        fileName; % Variable to hold path for ultrasound/DICOM image to be renamed
        newFilename; % Variable for new name (if modified from string determined by computer vision)

        roi = [1, 50, 896, 500]; % Region of Interest (ROI) to use for initial computer vision detection of text on image
        roi_rectangle; % Variable for user-selectable rectangle to modify ROI

        summary; % Variable linked to output text file which details renamed files from session
        version = 3.0; % Variable to track software version

        fileManufacturer; % Variable for DICOM manufacturer data
        fileModel; % Variable for DICOM instrument model data
    end

    methods (Access = private)

        function US_desc = ImageStringDetect(app)
            % Description: This function manipulates the ultrasound image
            % to make it grey-scale, inverts the colors (so the text is
            % a dark color on a white background), uses optical character
            % recognition (OCR) tools to detect text within a region of
            % interest (ROI), and then outputs the identified string as a
            % potential file-name to rename the image

            Igray = im2gray(app.US_Image);
            Ibinary = imbinarize(Igray);
            Icomplement = imcomplement(Ibinary);
            output = ocr(Icomplement,app.roi);
            US_desc = strip(output.Text);
            US_desc = splitlines(US_desc);
            US_desc = US_desc{1};
            US_desc = regexprep(US_desc, ' ', '_');
        end

        function BadCharacterRemoval(app)
            BadChar = '<>:"|?*!@#$%^&()[]{}|';

            bad = ismember(BadChar, app.newFilename);

            if any(bad)
                message = ["Name contains bad characters: ", BadChar(bad)];
                uialert(app.UltrasoundRenameToolUIFigure, message, "Warning","Icon","warning");
            end

            for i = 1:1:length(BadChar)
                app.newFilename = erase(app.newFilename, BadChar(i));
            end
        end

      

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: SelectUltrasoundDirectoryButton
        function SelectUltrasoundDirectoryButtonPushed(app, event)
            % Description: Function to scan directory selected by user to
            % and create fileList of all DICOM/ultrasound images for
            % renaming.

            % Get directory for renaming from user
            app.image_path = uigetdir('', "Select ultrasound image directory");
            app.renameTracker = 1;

            % Navigate to renaming directory, get list of all files in
            % directory (exclude directories from listing)

            try
                cd(app.image_path)
            catch
                figure(app.UltrasoundRenameToolUIFigure);
                return
            end

            list = dir('**/*');
            dirFlags = [list.isdir];
            fileFlags = ~dirFlags;
            app.filelist = list(fileFlags);

            % Clean up file-list to remove potential hidden files and
            % files, text files, or non-DICOM images from list.
            fileLen = length(app.filelist);
            i = 1;
            while(i <= fileLen)
                try
                    % Setting path/name for ultrasound/DICOM image to view and
                    if(ispc)
                        app.fileName = strcat(app.filelist(i).folder, "\", app.filelist(i).name);
                    else
                        app.fileName = strcat(app.filelist(i).folder, "/", app.filelist(i).name);
                    end
                    app.info = dicominfo(app.fileName);
                    i = i+1;
                catch
                    app.filelist(i) = [];
                    fileLen = fileLen - 1;
                end

            end

            app.summary = fopen("summary.txt", 'at+' );
            fprintf(app.summary, "Rename Session Start: ");
            fprintf(app.summary, string(datetime));
            fprintf(app.summary, '\n');
            fclose(app.summary);

            % Open current ultrasound/DICOM image to get meta-data (info),
            % image data (US_Image), and show image data in GUI
            while(app.renameTracker < fileLen)
                try
                    % Setting path/name for ultrasound/DICOM image to view and
                    % rename
                    if(ispc)
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "\", app.filelist(app.renameTracker).name);
                    else
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "/", app.filelist(app.renameTracker).name);
                    end

                    app.info = dicominfo(app.fileName);
                    app.US_Image = dicomread(app.info);
                    imshow(app.US_Image,'Parent',app.ImageAxes);
                    break;
                catch
                    % If file is not in the proper DICOM format or there is
                    % not an image within the file, generate an error and
                    % report to the summary log file
                    warning(strcat('Problem opening: ', app.fileName));
                    app.summary = fopen("summary.txt", 'at+' );
                    fprintf(app.summary, "Error Opening File: ");
                    fprintf(app.summary, app.filelist(app.renameTracker).folder);
                    if(ispc)
                        fprintf(app.summary, "\");
                    else
                        fprintf(app.summary, "/");
                    end
                    fprintf(app.summary, app.filelist(app.renameTracker).name);
                    fprintf(app.summary, " (File Skipped)");
                    fprintf(app.summary, '\n');
                    fclose(app.summary);
                    app.filelist(app.renameTracker) = [];
                    fileLen = fileLen - 1;
                end
            end

            app.roi(1) = 1;
            app.roi(2) = 1;
            if(~isempty(app.info.Width))
                app.roi(3) = app.info.Width-app.roi(1);
            end

            if(~isempty(app.info.Height))
                app.roi(4) = app.info.Height-app.roi(2);
            end
            app.fileManufacturer = app.info.Manufacturer;
            app.fileModel = app.info.ManufacturerModelName;

            % Create potential filename using OCR detected string from
            % ultrasound image and remove characters that could cause
            % saving issues in filesystems
            try
                US_desc = ImageStringDetect(app);
                app.newFilename = strcat(app.info.PatientID, "_", US_desc);
                BadCharacterRemoval(app);
            catch
                % If OCR fails, generate a warning, report to log file,
                % and return filename that only uses patient ID metadata
                warning(strcat('Problem applying OCR: ', app.fileName));
                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Problem applying OCR: ");
                fprintf(app.summary, app.filelist(app.renameTracker).folder);
                if(ispc)
                        fprintf(app.summary, "\");
                else
                        fprintf(app.summary, "/");
                end
                fprintf(app.summary, app.filelist(app.renameTracker).name);
                fprintf(app.summary, " (Auto-naming Skipped)");
                fprintf(app.summary, '\n');
                fclose(app.summary);
                app.newFilename = strcat(app.info.PatientID, "_");
            end

            % Update the GUI with information about the overall renaming
            % process.
            %   PatientID: patient identifier from DICOM meta-data which
            %   will be used as the prefix to rename the file
            %   CurrentImageText: Current images out of total images to give
            %   indicator of renaming progress
            %   TotalImages: Total images to be renamed
            %   ImageName: Existing filename of image to rename
            app.ParticipantIDTextArea.Value = app.info.PatientID;
            app.CurrentImageTextArea.Value = num2str(app.renameTracker);
            app.TotalImagesTextArea.Value = num2str(length(app.filelist));
            app.ImageNameTextArea.Value = app.filelist(app.renameTracker).name;

            % Update the GUI with information about the new name
            % OCRImageName: Suggested name based on text identified in
            % image using the optical character recognition tool
            % NewImageNameEdit: Suggested start of new name using
            % ParticipantID, to be used in cases where OCR fails / no text
            % is present on the image to use
            app.OCRImageNameTextArea.Value = app.newFilename;
            app.NewImageNameEditField.Value = strcat(app.info.PatientID, "_");

        end

        % Button pushed function: RenameButton
        function RenameButtonPushed(app, event)
            % Description: Function to complete renaming actions which
            % includes:
            %   1) Setup new directories to sort renamed images by participant
            %   2) Check filenames for characters that may cause problems
            %   3) Check filename is unique so previous images not overwritten
            %   4) Copy DICOM/ultrasound image to new directory with new name
            %   5) Open next file for viewing / naming

            % Checking if a directory to store the renamed files exists, if not
            % creates it
            if not(isfolder("Renamed"))
                mkdir Renamed
            end

            if(ispc)
                renameStr = "Renamed\";
                renameStr2 = "\Renamed\";
            else
                renameStr = "Renamed/";
                renameStr2 = "/Renamed/";
            end

            % Checking if directory for unique participant exists to save
            % renamed file, if not creates it
            if not(isfolder(strcat(renameStr, app.info.PatientID)))
                mkdir( strcat(renameStr, app.info.PatientID));
            end

            if(~strcmp(app.NewImageNameEditField.Value, strcat(app.info.PatientID, "_")))
                app.newFilename = app.NewImageNameEditField.Value;
            end

            BadCharacterRemoval(app);

            % Check if the filename that will be used to rename the current
            % image exists already in the directory, if it does revise name
            % to include _X where X is a number to differentiate it from
            % the existing filename.
            % This code also searches the directory for other _X filenames
            % and finds an appropriate value to again prevent overwriting a
            % file.  Currently limited to having 5000 files with the same
            % name.
            if exist(strcat(app.image_path, renameStr2, app.info.PatientID, "/", app.newFilename) , 'file') == 2
                for N = 2:1:5000
                    if exist(strcat(app.image_path, renameStr2, app.info.PatientID, "/", app.newFilename, "_", num2str(N)), 'file') == 2
                    else
                        app.newFilename = strcat(app.newFilename, "_", num2str(N));
                        message = ["Duplicate Filename",strcat("Revised to: ", app.newFilename) ];
                        uialert(app.UltrasoundRenameToolUIFigure,message,"Warning","Icon","warning");
                        break;
                    end
                end
            end

            % Copy ultrasound/DICOM file to new folder (based on
            % participant identified) with new filename
            copyfile(app.fileName, strcat(app.image_path, renameStr2, app.info.PatientID, "/", app.newFilename));
            app.summary = fopen("summary.txt", 'at+' );
            fprintf(app.summary, "DICOM File: ");
            fprintf(app.summary, app.filelist(app.renameTracker).folder);
                    if(ispc)
                        fprintf(app.summary, "\");
                    else
                        fprintf(app.summary, "/");
                    end
            fprintf(app.summary, app.filelist(app.renameTracker).name);
            fprintf(app.summary, " copied/renamed ");
            fprintf(app.summary, app.newFilename);
            fprintf(app.summary, '\n');
            fclose(app.summary);

            app.renameTracker = app.renameTracker + 1;
            if(app.renameTracker > length(app.filelist))
                message = "All files renamed! You can close the app now.";
                uialert(app.UltrasoundRenameToolUIFigure,message,"success","Icon","success");

                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Rename Session Close: ");
                fprintf(app.summary, string(datetime));
                fprintf(app.summary, '\n');
                fclose(app.summary);
                return;
            end

            % Open current ultrasound/DICOM image to get meta-data (info),
            % image data (US_Image), and show image data in GUI
            fileLen = length(app.filelist);
            while(app.renameTracker < fileLen)
                try
                    if(ispc)
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "\", app.filelist(app.renameTracker).name);
                    else
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "/", app.filelist(app.renameTracker).name);
                    end

                    app.info = dicominfo(app.fileName);
                    app.US_Image = dicomread(app.info);
                    imshow(app.US_Image,'Parent',app.ImageAxes);
                    break;
                catch
                    % If file is not in the proper DICOM format or there is
                    % not an image within the file, generate an error and
                    % report to the summary log file
                    warning(strcat('Problem opening: ', app.fileName));
                    app.summary = fopen("summary.txt", 'at+' );
                    fprintf(app.summary, "Error Opening File: ");
                    fprintf(app.summary, app.filelist(app.renameTracker).folder);
                    if(ispc)
                        fprintf(app.summary, "\");
                    else
                        fprintf(app.summary, "/");
                    end
                    fprintf(app.summary, app.filelist(app.renameTracker).name);
                    fprintf(app.summary, " (File Skipped)");
                    fprintf(app.summary, '\n');
                    fclose(app.summary);
                    app.filelist(app.renameTracker) = [];
                    fileLen = fileLen - 1;
                end
            end


            if (~strcmp(app.fileManufacturer, app.info.Manufacturer) && ~strcmp(app.fileModel, app.info.ManufacturerModelName))
                app.roi(1) = 1;
                app.roi(2) = 1;
                if(~isempty(app.info.Width))
                    app.roi(3) = app.info.Width-app.roi(1);
                end

                if(~isempty(app.info.Height))
                    app.roi(4) = app.info.Height-app.roi(2);
                end

                app.fileManufacturer = app.info.Manufacturer;
                app.fileModel = app.info.ManufacturerModelName;
            end

            try
                % Analyze image for text that can be used to rename current
                % image
                US_desc = ImageStringDetect(app);

                % Create potential filename using OCR detected string from
                % ultrasound image and remove characters that could cause
                % saving issues in filesystems
                app.newFilename = strcat(app.info.PatientID, "_", US_desc);
                BadCharacterRemoval(app);
            catch
                % If OCR fails, generate a warning, report to log file,
                % and return filename that only uses patient ID metadata
                warning(strcat('Problem applying OCR: ', app.fileName));
                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Problem applying OCR: ");
                fprintf(app.summary, app.filelist(app.renameTracker).folder);
                if(ispc)
                        fprintf(app.summary, "\");
                else
                        fprintf(app.summary, "/");
                end
                fprintf(app.summary, app.filelist(app.renameTracker).name);
                fprintf(app.summary, " (Auto-naming Skipped)");
                fprintf(app.summary, '\n');
                fclose(app.summary);
                app.newFilename = strcat(app.info.PatientID, "_");
            end


            % Update the GUI with information about the overall renaming
            % process.
            %   PatientID: patient identifier from DICOM meta-data which
            %   will be used as the prefix to rename the file
            %   CurrentImageText: Current images out of total images to give
            %   indicator of renaming progress
            %   TotalImages: Total images to be renamed
            %   ImageName: Existing filename of image to rename
            app.ParticipantIDTextArea.Value = app.info.PatientID;
            app.CurrentImageTextArea.Value = num2str(app.renameTracker);
            app.TotalImagesTextArea.Value = num2str(length(app.filelist));
            app.ImageNameTextArea.Value = app.filelist(app.renameTracker).name;


            % Update the GUI with information about the new name
            % OCRImageName: Suggested name based on text identified in
            % image using the optical character recognition tool
            % NewImageNameEdit: Suggested start of new name using
            % ParticipantID, to be used in cases where OCR fails / no text
            % is present on the image to use
            app.OCRImageNameTextArea.Value = app.newFilename;
            app.NewImageNameEditField.Value = strcat(app.info.PatientID, "_");

            % If ROI check-box is selected, draw red rectangle on screen
            % that shows user the area in the image that is the region of
            % interest for the optical character detection function
            if(app.ShowROICheckBox.Value == 1)
                app.roi_rectangle = drawrectangle(app.ImageAxes,'Position',app.roi,'Color','r');
            else
                delete(app.roi_rectangle);
            end

        end

        % Value changed function: ShowROICheckBox
        function ShowROICheckBoxValueChanged(app, event)

            if(app.ShowROICheckBox.Value == 1)
                app.roi_rectangle = drawrectangle(app.ImageAxes,'Position',app.roi,'Color','r');
            else
                delete(app.roi_rectangle);
            end
        end

        % Button pushed function: ReviseROIButton
        function ReviseROIButtonPushed(app, event)
            % Description: Provides option to draw new rectangular region
            % of interest to be used in the optical character detection
            % process.

            delete(app.roi_rectangle);
            app.roi_rectangle = drawrectangle(app.ImageAxes, 'Color','r');
            app.roi = app.roi_rectangle.Position;

            if(app.roi(1) < 1)
                app.roi(1) = 1;
            end

            if(app.roi(2) < 1)
                app.roi(2) = 1;
            end

            if(app.roi(1)+app.roi(3) > app.info.Width)
                app.roi(3) = app.info.Width-app.roi(1);
            end

            if(app.roi(2)+app.roi(4) > app.info.Height)
                app.roi(4) = app.info.Height-app.roi(2);
            end
            app.roi_rectangle.Position = app.roi;


            app.ShowROICheckBox.Value = 1;

            % Analyze image for text that can be used to rename current
            % image
            try
                US_desc = ImageStringDetect(app);
                app.newFilename = strcat(app.info.PatientID, "_", US_desc);
                BadCharacterRemoval(app);
            catch
                % If OCR fails, generate a warning, report to log file,
                % and return filename that only uses patient ID metadata
                warning(strcat('Problem applying OCR: ', app.fileName));
                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Problem applying OCR: ");
                fprintf(app.summary, app.filelist(app.renameTracker).folder);
                if(ispc)
                        fprintf(app.summary, "\");
                else
                        fprintf(app.summary, "/");
                end
                fprintf(app.summary, app.filelist(app.renameTracker).name);
                fprintf(app.summary, " (Auto-naming Skipped)");
                fprintf(app.summary, '\n');
                fclose(app.summary);
                app.newFilename = strcat(app.info.PatientID, "_");
            end

            % Update the GUI with information about the new name
            % OCRImageName: Suggested name based on text identified in
            % image using the optical character recognition tool
            % NewImageNameEdit: Suggested start of new name using
            % ParticipantID, to be used in cases where OCR fails / no text
            % is present on the image to use
            app.OCRImageNameTextArea.Value = app.newFilename;
            app.NewImageNameEditField.Value = strcat(app.info.PatientID, "_");

        end

        % Button pushed function: BackButton
        function BackButtonPushed(app, event)
            % Description: Provides functionality to navigate through
            % previous images in the overall filelist without having to
            % rename them

            if(app.renameTracker <= 1)
                app.renameTracker = length(app.filelist);
            else
                app.renameTracker = app.renameTracker - 1;
            end

            % Open current ultrasound/DICOM image to get meta-data (info),
            % image data (US_Image), and show image data in GUI
            while(app.renameTracker >= 1)
                try
                    if(ispc)
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "\", app.filelist(app.renameTracker).name);
                    else
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "/", app.filelist(app.renameTracker).name);
                    end

                    app.info = dicominfo(app.fileName);
                    app.US_Image = dicomread(app.info);
                    imshow(app.US_Image,'Parent',app.ImageAxes);
                    break;
                catch
                    % If file is not in the proper DICOM format or there is
                    % not an image within the file, generate an error and
                    % report to the summary log file
                    warning(strcat('Problem opening: ', app.fileName));
                    app.summary = fopen("summary.txt", 'at+' );
                    fprintf(app.summary, "Error Opening File: ");
                    fprintf(app.summary, app.filelist(app.renameTracker).folder);
                    if(ispc)
                        fprintf(app.summary, "\");
                    else
                        fprintf(app.summary, "/");
                    end
                    fprintf(app.summary, app.filelist(app.renameTracker).name);
                    fprintf(app.summary, " (File Skipped)");
                    fprintf(app.summary, '\n');
                    fclose(app.summary);
                    app.filelist(app.renameTracker) = [];
                    fileLen = fileLen - 1;
                end
            end

            % If there is a change in the manufacturer and/or manufacturer
            % model name in the DICOM meta-data, this could mean images
            % have a different file size.  To handle this, revise the ROI
            % using the width/height meta-data
            if (~strcmp(app.fileManufacturer, app.info.Manufacturer) && ~strcmp(app.fileModel, app.info.ManufacturerModelName))
                app.roi(1) = 1;
                app.roi(2) = 1;
                if(~isempty(app.info.Width))
                    app.roi(3) = app.info.Width-app.roi(1);
                end

                if(~isempty(app.info.Height))
                    app.roi(4) = app.info.Height-app.roi(2);
                end

                app.fileManufacturer = app.info.Manufacturer;
                app.fileModel = app.info.ManufacturerModelName;
            end


            % Create potential filename using OCR detected string from
            % ultrasound image and remove characters that could cause
            % saving issues in filesystems
            try
                US_desc = ImageStringDetect(app);
                app.newFilename = strcat(app.info.PatientID, "_", US_desc);
                BadCharacterRemoval(app);
            catch
                % If OCR fails, generate a warning, report to log file,
                % and return filename that only uses patient ID metadata
                warning(strcat('Problem applying OCR: ', app.fileName));
                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Problem applying OCR: ");
                fprintf(app.summary, app.filelist(app.renameTracker).folder);
                if(ispc)
                        fprintf(app.summary, "\");
                else
                        fprintf(app.summary, "/");
                end
                fprintf(app.summary, app.filelist(app.renameTracker).name);
                fprintf(app.summary, " (Auto-naming Skipped)");
                fprintf(app.summary, '\n');
                fclose(app.summary);
                app.newFilename = strcat(app.info.PatientID, "_");
            end

            % Update the GUI with information about the overall renaming
            % process.
            %   PatientID: patient identifier from DICOM meta-data which
            %   will be used as the prefix to rename the file
            %   CurrentImageText: Current images out of total images to give
            %   indicator of renaming progress
            %   TotalImages: Total images to be renamed
            %   ImageName: Existing filename of image to rename
            app.ParticipantIDTextArea.Value = app.info.PatientID;
            app.CurrentImageTextArea.Value = num2str(app.renameTracker);
            app.TotalImagesTextArea.Value = num2str(length(app.filelist));
            app.ImageNameTextArea.Value = app.filelist(app.renameTracker).name;

            % Update the GUI with information about the new name
            % OCRImageName: Suggested name based on text identified in
            % image using the optical character recognition tool
            % NewImageNameEdit: Suggested start of new name using
            % ParticipantID, to be used in cases where OCR fails / no text
            % is present on the image to use
            app.OCRImageNameTextArea.Value = app.newFilename;
            app.NewImageNameEditField.Value = strcat(app.info.PatientID, "_");

            if(app.ShowROICheckBox.Value == 1)
                app.roi_rectangle = drawrectangle(app.ImageAxes,'Position',app.roi,'Color','r');
            else
                delete(app.roi_rectangle);
            end
        end

        % Button pushed function: ForwardButton
        function ForwardButtonPushed(app, event)
            % Description: Provides functionality to navigate to
            % next image in the overall filelist without having to
            % rename/save existing file

            if(app.renameTracker >= length(app.filelist))
                app.renameTracker = 1;
            else
                app.renameTracker = app.renameTracker + 1;
            end

            % Open current ultrasound/DICOM image to get meta-data (info),
            % image data (US_Image), and show image data in GUI
            fileLen = length(app.filelist);
            while(app.renameTracker < fileLen)
                try
                    if(ispc)
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "\", app.filelist(app.renameTracker).name);
                    else
                        app.fileName = strcat(app.filelist(app.renameTracker).folder, "/", app.filelist(app.renameTracker).name);
                    end

                    app.info = dicominfo(app.fileName);
                    app.US_Image = dicomread(app.info);
                    imshow(app.US_Image,'Parent',app.ImageAxes);
                    break;
                catch
                    % If file is not in the proper DICOM format or there is
                    % not an image within the file, generate an error and
                    % report to the summary log file
                    warning(strcat('Problem opening: ', app.fileName));
                    app.summary = fopen("summary.txt", 'at+' );
                    fprintf(app.summary, "Error Opening File: ");
                    fprintf(app.summary, app.filelist(app.renameTracker).folder);
                    if(ispc)
                        fprintf(app.summary, "\");
                    else
                        fprintf(app.summary, "/");
                    end
                    fprintf(app.summary, app.filelist(app.renameTracker).name);
                    fprintf(app.summary, " (File Skipped)");
                    fprintf(app.summary, '\n');
                    fclose(app.summary);
                    app.filelist(app.renameTracker) = [];
                    fileLen = fileLen - 1;
                end
            end


            if (~strcmp(app.fileManufacturer, app.info.Manufacturer) && ~strcmp(app.fileModel, app.info.ManufacturerModelName))
                app.roi(1) = 1;
                app.roi(2) = 1;
                if(~isempty(app.info.Width))
                    app.roi(3) = app.info.Width-app.roi(1);
                end

                if(~isempty(app.info.Height))
                    app.roi(4) = app.info.Height-app.roi(2);
                end

                app.fileManufacturer = app.info.Manufacturer;
                app.fileModel = app.info.ManufacturerModelName;
            end


            % Create potential filename using OCR detected string from
            % ultrasound image and remove characters that could cause
            % saving issues in filesystems
            try
                US_desc = ImageStringDetect(app);
                app.newFilename = strcat(app.info.PatientID, "_", US_desc);
                BadCharacterRemoval(app);
            catch
                % If OCR fails, generate a warning, report to log file,
                % and return filename that only uses patient ID metadata
                warning(strcat('Problem applying OCR: ', app.fileName));
                app.summary = fopen("summary.txt", 'at+' );
                fprintf(app.summary, "Problem applying OCR: ");
                fprintf(app.summary, app.filelist(app.renameTracker).folder);
                if(ispc)
                        fprintf(app.summary, "\");
                else
                        fprintf(app.summary, "/");
                end
                fprintf(app.summary, app.filelist(app.renameTracker).name);
                fprintf(app.summary, " (Auto-naming Skipped)");
                fprintf(app.summary, '\n');
                fclose(app.summary);
                app.newFilename = strcat(app.info.PatientID, "_");
            end

            % Update the GUI with information about the overall renaming
            % process.
            %   PatientID: patient identifier from DICOM meta-data which
            %   will be used as the prefix to rename the file
            %   CurrentImageText: Current images out of total images to give
            %   indicator of renaming progress
            %   TotalImages: Total images to be renamed
            %   ImageName: Existing filename of image to rename
            app.ParticipantIDTextArea.Value = app.info.PatientID;
            app.CurrentImageTextArea.Value = num2str(app.renameTracker);
            app.TotalImagesTextArea.Value = num2str(length(app.filelist));
            app.ImageNameTextArea.Value = app.filelist(app.renameTracker).name;

            % Update the GUI with information about the new name
            % OCRImageName: Suggested name based on text identified in
            % image using the optical character recognition tool
            % NewImageNameEdit: Suggested start of new name using
            % ParticipantID, to be used in cases where OCR fails / no text
            % is present on the image to use
            app.OCRImageNameTextArea.Value = app.newFilename;
            app.NewImageNameEditField.Value = strcat(app.info.PatientID, "_");

            if(app.ShowROICheckBox.Value == 1)
                app.roi_rectangle = drawrectangle(app.ImageAxes,'Position',app.roi,'Color','r');
            else
                delete(app.roi_rectangle);
            end


        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UltrasoundRenameToolUIFigure and hide until all components are created
            app.UltrasoundRenameToolUIFigure = uifigure('Visible', 'off');
            app.UltrasoundRenameToolUIFigure.Position = [100 100 660 667];
            app.UltrasoundRenameToolUIFigure.Name = 'Ultrasound Rename Tool';

            % Create ImageAxes
            app.ImageAxes = uiaxes(app.UltrasoundRenameToolUIFigure);
            title(app.ImageAxes, 'Ultrasound Image to Rename:')
            app.ImageAxes.XTick = [];
            app.ImageAxes.XTickLabel = {'[ ]'};
            app.ImageAxes.YTick = [];
            app.ImageAxes.Position = [13 239 638 390];

            % Create SelectUltrasoundDirectoryButton
            app.SelectUltrasoundDirectoryButton = uibutton(app.UltrasoundRenameToolUIFigure, 'push');
            app.SelectUltrasoundDirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @SelectUltrasoundDirectoryButtonPushed, true);
            app.SelectUltrasoundDirectoryButton.FontWeight = 'bold';
            app.SelectUltrasoundDirectoryButton.Position = [40 203 174 22];
            app.SelectUltrasoundDirectoryButton.Text = 'Select Ultrasound Directory';

            % Create RenameButton
            app.RenameButton = uibutton(app.UltrasoundRenameToolUIFigure, 'push');
            app.RenameButton.ButtonPushedFcn = createCallbackFcn(app, @RenameButtonPushed, true);
            app.RenameButton.FontWeight = 'bold';
            app.RenameButton.Position = [489 29 100 22];
            app.RenameButton.Text = 'Rename';

            % Create TotalImagesTextAreaLabel
            app.TotalImagesTextAreaLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.TotalImagesTextAreaLabel.HorizontalAlignment = 'right';
            app.TotalImagesTextAreaLabel.Position = [37 126 77 22];
            app.TotalImagesTextAreaLabel.Text = 'Total Images:';

            % Create TotalImagesTextArea
            app.TotalImagesTextArea = uitextarea(app.UltrasoundRenameToolUIFigure);
            app.TotalImagesTextArea.HorizontalAlignment = 'center';
            app.TotalImagesTextArea.Position = [129 127 64 21];

            % Create CurrentImageTextAreaLabel
            app.CurrentImageTextAreaLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.CurrentImageTextAreaLabel.HorizontalAlignment = 'right';
            app.CurrentImageTextAreaLabel.Position = [29 94 85 22];
            app.CurrentImageTextAreaLabel.Text = 'Current Image:';

            % Create CurrentImageTextArea
            app.CurrentImageTextArea = uitextarea(app.UltrasoundRenameToolUIFigure);
            app.CurrentImageTextArea.HorizontalAlignment = 'center';
            app.CurrentImageTextArea.Position = [129 96 64 21];

            % Create ParticipantIDTextAreaLabel
            app.ParticipantIDTextAreaLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.ParticipantIDTextAreaLabel.HorizontalAlignment = 'right';
            app.ParticipantIDTextAreaLabel.Position = [33 30 82 22];
            app.ParticipantIDTextAreaLabel.Text = 'Participant ID:';

            % Create ParticipantIDTextArea
            app.ParticipantIDTextArea = uitextarea(app.UltrasoundRenameToolUIFigure);
            app.ParticipantIDTextArea.HorizontalAlignment = 'center';
            app.ParticipantIDTextArea.Position = [130 32 133 21];

            % Create NewImageNameLabel
            app.NewImageNameLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.NewImageNameLabel.HorizontalAlignment = 'right';
            app.NewImageNameLabel.Position = [326 67 105 22];
            app.NewImageNameLabel.Text = 'New Image Name:';

            % Create NewImageNameEditField
            app.NewImageNameEditField = uieditfield(app.UltrasoundRenameToolUIFigure, 'text');
            app.NewImageNameEditField.Position = [447 67 185 22];

            % Create ImageNameTextAreaLabel
            app.ImageNameTextAreaLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.ImageNameTextAreaLabel.HorizontalAlignment = 'right';
            app.ImageNameTextAreaLabel.Position = [38 62 77 22];
            app.ImageNameTextAreaLabel.Text = 'Image Name:';

            % Create ImageNameTextArea
            app.ImageNameTextArea = uitextarea(app.UltrasoundRenameToolUIFigure);
            app.ImageNameTextArea.HorizontalAlignment = 'center';
            app.ImageNameTextArea.Position = [130 64 132 21];

            % Create OCRImageNameLabel
            app.OCRImageNameLabel = uilabel(app.UltrasoundRenameToolUIFigure);
            app.OCRImageNameLabel.HorizontalAlignment = 'right';
            app.OCRImageNameLabel.Position = [325 99 106 22];
            app.OCRImageNameLabel.Text = 'OCR Image Name:';

            % Create OCRImageNameTextArea
            app.OCRImageNameTextArea = uitextarea(app.UltrasoundRenameToolUIFigure);
            app.OCRImageNameTextArea.Position = [447 100 184 21];

            % Create ShowROICheckBox
            app.ShowROICheckBox = uicheckbox(app.UltrasoundRenameToolUIFigure);
            app.ShowROICheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowROICheckBoxValueChanged, true);
            app.ShowROICheckBox.Text = 'Show ROI';
            app.ShowROICheckBox.Position = [373 137 76 22];

            % Create ReviseROIButton
            app.ReviseROIButton = uibutton(app.UltrasoundRenameToolUIFigure, 'push');
            app.ReviseROIButton.ButtonPushedFcn = createCallbackFcn(app, @ReviseROIButtonPushed, true);
            app.ReviseROIButton.Position = [490 137 100 22];
            app.ReviseROIButton.Text = 'Revise ROI';

            % Create BackButton
            app.BackButton = uibutton(app.UltrasoundRenameToolUIFigure, 'push');
            app.BackButton.ButtonPushedFcn = createCallbackFcn(app, @BackButtonPushed, true);
            app.BackButton.Position = [47 165 58 25];
            app.BackButton.Text = 'Back';

            % Create ForwardButton
            app.ForwardButton = uibutton(app.UltrasoundRenameToolUIFigure, 'push');
            app.ForwardButton.ButtonPushedFcn = createCallbackFcn(app, @ForwardButtonPushed, true);
            app.ForwardButton.Position = [129 165 60 25];
            app.ForwardButton.Text = 'Forward';

            % Show the figure after all components are created
            app.UltrasoundRenameToolUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = US_DICOM_Renamer

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UltrasoundRenameToolUIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UltrasoundRenameToolUIFigure)
        end
    end
end
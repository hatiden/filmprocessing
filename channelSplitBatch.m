function result = netODBatch(app, preDir, outDir, chann)
% NetODbatch function takes in a directory of pre scans, a directory of
% post scans and outputs a directory of netOD files.
% KK 24/07/2018

% In case there is nothing in the arguments
if(nargin<3)
    outDir = '.\A Individual BatchTest';
    chann = 1;
end

includeSubdirectories = false;

% All extensions that can be read by IMREAD
imreadFormats       = imformats;
supportedExtensions = [imreadFormats.ext];
% Add dicom extensions
supportedExtensions{end+1} = 'dcm';
supportedExtensions{end+1} = 'ima';
supportedExtensions = strcat('.',supportedExtensions);
% Allow the 'no extension' specification of DICOM
supportedExtensions{end+1} = '';

             
% Create a image data store that can read all these files
preDS = datastore(preDir,...
    'IncludeSubfolders', includeSubdirectories,...
    'Type','image',...
    'FileExtensions',supportedExtensions);
preDS.ReadFcn = @readSupportedImage;

% Initialise progress bar for UI
d = uiprogressdlg(app.ChannelSplitter, 'Title','Splitting Images',...
        'Message','1','Cancelable','on');



% Process each image: register, divide and NetOD.
for imgInd = 1:numel(preDS.Files)
    
    % Allow user to cancel using the progress bar
    if d.CancelRequested
        break
    end
    

    
    preImageFile  = preDS.Files{imgInd};
        
    % Output has the same directory structure as input
    outfilename = strrep(preImageFile, preDir, outDir);
    % Remove the file extension to create the template output file name
    [outpath, filename,~] = fileparts(outfilename);
    outImageFile = fullfile(outpath,filename);
    

    
    try
        % Read
        pre = preDS.readimage(imgInd);
        
        split = pre(:,:,1);
       
        % Write chosen fields to image files only if output directory is
        % specified
        if(~isempty(outDir))
            % Create (sub)directory if needed
            outSubDir = fileparts(outImageFile);
            createDirectory(outSubDir); %function below checks if dir exists
            
            splitfilename = ['Split_', filename]
            splitFileWithExtension = [fullfile(outpath, ...
                splitfilename),'.tiff'];
                        
            % Update progress bar value based on how many files have been
            % processed so far.
            d.Value = imgInd/numel(preDS.Files);
            d.Message = sprintf('Current file: %s', splitFileWithExtension);    
            
            try

                % Calls tiffwrite function below. I needed this because
                % imwrite does not support 32 uint, or single precision
                % tiffs.
                imwrite(split, splitFileWithExtension);
              

                
            catch IMWRITEFAIL
               disp(['WRITE FAILED:', preImageFile]);
               warning(IMWRITEFAIL.identifier, IMWRITEFAIL.message);
            end
          
        end
        
        disp(['PASSED:', preImageFile]);
        
    catch READANDPROCESSEXCEPTION
       disp(['FAILED:', preImageFile]);
       warning(READANDPROCESSEXCEPTION.identifier, READANDPROCESSEXCEPTION.message);
    end
    
end

close(d);

end

% Saving to 32 bit tiff is not supported by imwrite. This functions will
% create tags based on what type of image is detected and write to
% appropriate tiff file. 32 uint with single precision is needed to extract
% the data from the netOD files.

function tiffwrite(im, imname)
    
    if isa(im, 'uint16')
        tagstruct.BitsPerSample   = 16;
        tagstruct.SampleFormat    = Tiff.SampleFormat.UInt;
    elseif isa(im, 'single')
        tagstruct.BitsPerSample   = 32;
        tagstruct.SampleFormat    = Tiff.SampleFormat.IEEEFP;
    end
    
    t                         = Tiff(imname, 'w');
    tagstruct.ImageLength     = size(im, 1);
    tagstruct.ImageWidth      = size(im, 2);
    tagstruct.Photometric     = Tiff.Photometric.MinIsBlack;
    
    tagstruct.SamplesPerPixel = 1; 
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.Compression     = Tiff.Compression.None; 
    setTag(t, tagstruct);
    t.write(im);
    t.close();
end


function img = readSupportedImage(imgFile)
% Image read function with DICOM support
if(isdicom(imgFile))
    img = dicomread(imgFile);
else
    img = imread(imgFile);
end
end

function createDirectory(dirname)
% Make output (sub) directory if needed
if exist(dirname, 'dir')
    return;
end

[success, message] = mkdir(dirname);
if ~success
    disp(['FAILED TO CREATE:', dirname]);
    disp(message);
end
end

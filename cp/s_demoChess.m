%%
% Demo some advantages of GPU rendering
% using our computational photography (cp) framework
% 
% Developed by David Cardinal, Stanford University, 2021
%

ieInit();
% some timing code, just to see how fast we run...
setpref('ISET', 'benchmarkstart', cputime); 
setpref('ISET', 'tStart', tic);

% cpBurstCamera is a sub-class of cpCamera that implements simple HDR and Burst
% capture and processing
ourCamera = cpBurstCamera(); 

% We'll use a pre-defined sensor for our Camera Module, and let it use
% default optics for now. We can then assign the module to our camera:
sensor = sensorFromFile('ar0132atSensorRGB'); 
% Cameras can eventually have more than one module (lens + sensor)
% but for now, we just create one using our sensor
ourCamera.cmodules(1) = cpCModule('sensor', sensor); 

scenePath = 'ChessSet';
sceneName = 'ChessSet';
%scenePath = 'cornell_box';
%sceneName = 'cornell_box';

pbrtCPScene = cpScene('pbrt', 'scenePath', scenePath, 'sceneName', sceneName, ...
    'resolution', [64 64], ...
    'numRays', 32, 'sceneLuminance', 200);

% set scene FOV to align with camera
pbrtCPScene.thisR.recipeSet('fov',60);

% set the camera in motion
% settings for a nice slow 6fps video:
% pbrtCPScene.cameraMotion = {{'unused', [0, .005, 0], [-.5, 0, 0]}};
pbrtCPScene.cameraMotion = {{'unused', [0, .01, 0], [-1, 0, 0]}};


videoFrames = ourCamera.TakePicture(pbrtCPScene, ...
    'Video', 'numVideoFrames', 3, 'imageName','Video with Camera Motion');
%imtool(videoFrames{1});
if isunix
    chessVideo = VideoWriter('ChessSet', 'Motion JPEG AVI');
else
    % H.264 only works on Windows and Mac
    chessVideo = VideoWriter('ChessSet', 'MPEG-4');
end
chessVideo.FrameRate = 6;
chessVideo.Quality = 100;
open(chessVideo);
for ii = 1:numel(videoFrames)
    writeVideo(chessVideo,videoFrames{ii});
end
close (chessVideo);

% timing code
tTotal = toc(getpref('ISET','tStart'));
afterTime = cputime;
beforeTime = getpref('ISET', 'benchmarkstart', 0);
glData = opengl('data');
disp(strcat("Local cpCam ran  on: ", glData.Vendor, " ", glData.Renderer, "with driver version: ", glData.Version)); 
disp(strcat("Local cpCam ran  in: ", string(afterTime - beforeTime), " seconds of CPU time."));
disp(strcat("Total cpCam ran  in: ", string(tTotal), " total seconds."));




%% Create a sensor with a rectangular pixel
%
%  Illustrates how to create a sensor for dual pixel autofocus experiments
%  (DPAF).
%
%  In other scripts within ISET3d we create the sensor and put a single
%  microlens on top of the two pixels.
%
% See also
%  s_sensorDPAFMicrolens (ISET3d)


%% Initialize a scene and oi
ieInit;

s_initSO;

%% Make a dual pixel sensor that has rectangular pixels

% The sensor has twice as many columns as rows.
% Each pixel is rectangular with 2.8 um height and 1.4 micron width.

% This is what happens when you call
%
%  sensor = sensorCreate('dual pixel');
%

sensor = sensorCreate;
sz = sensorGet(sensor,'pixel size');

% We make the height
sensor = sensorSet(sensor,'pixel width',sz(2)/2);

% Add more columns
rowcol = sensorGet(sensor,'size');
sensor = sensorSet(sensor,'size',[rowcol(1)*2, rowcol(2)*4]);

% Set the CFA pattern accounting for the dual pixel architecture
sensor = sensorSet(sensor,'pattern',[2 2 1 1; 3 3 2 2]);


%% Compute the sensor data

% Notice that we get the spatial structure of the image right, even though
% the pixels are rectangular.
sensor = sensorCompute(sensor,oi);
sensorWindow(sensor);

%% END


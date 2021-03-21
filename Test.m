% Execute FfmpegVideoWriter for testing.

% Author: Rotem (Year 2021).

% 50 frames, resolution 512x384, and 25 fps
width = 512;
height = 384;
n_frames = 50;
fps = 25;

% Execute simple example - creates MP4 file with H.264 encoded video.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
v = FfmpegVideoWriter('c:\FFmpeg\bin\output.mp4');
v.ffmpeg_cmd = 'c:\FFmpeg\bin\ffmpeg.exe';
v.log_file = 'C:\FFmpeg\bin\ffmpeg_log.txt';
v.framerate = fps;
v.pix_fmt = 'yuv444p';
v.vcodec = 'libx264';
v.crf = 17;

open(v);

for i = 1:n_frames
    % Build synthetic image for testing.
    I = zeros(height, width, 3, 'uint8') + 60;
    I = insertText(I, [width/2 , height/2], num2str(i), 'FontSize', 160, ...
                   'BoxColor', [60, 60, 60], 'BoxOpacity', 1, ...
                   'TextColor', [30, 30, 255], 'AnchorPoint', 'Center');  % Blue number

    writeFrame(v, I);
end

close(v);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear v  % Clear v from MATLAB workspace (just for tesing).

% Test the case where the users are "advanced users", and decide to manually set FFmpeg command line.
% Create animated GIF.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
v = FfmpegVideoWriter();

v.log_file = 'C:\FFmpeg\bin\ffmpeg_log.txt';

% Manually set FFmpeg command line with arguments for encoding Animated GIF.
% https://superuser.com/questions/556029/how-do-i-convert-a-video-to-gif-using-ffmpeg-with-reasonable-quality
v.cmd = ['c:\FFmpeg\bin\ffmpeg.exe', ' -y -video_size ', num2str(width),'x', num2str(height), ...
         ' -pixel_format rgb24 -f rawvideo -framerate ', num2str(10), ...
         ' -color_primaries bt709 -color_trc bt709 -colorspace bt709', ...
         ' -i pipe:', ...
         ' -vf "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"', ...
         ' -loop 0 ', ...
         'c:\FFmpeg\bin\output.gif'];

open(v);

for i = 1:n_frames
    % Build synthetic image for testing
    I = zeros(height, width, 3, 'uint8') + 60;
    I = insertText(I, [width/2 , height/2], num2str(i), 'FontSize', 160, ...
                   'BoxColor', [60, 60, 60], 'BoxOpacity', 1, ...
                   'TextColor', [30, 30, 255], 'AnchorPoint', 'Center');  % Blue number

    writeFrame(v, I);
end

close(v);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


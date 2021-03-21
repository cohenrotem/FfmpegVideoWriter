# FfmpegVideoWriter
MATLAB class that uses FFmpeg for encoding video.

FfmpegVideoWriter Create a FFmpeg Video Writer object.

  Note: Requires MATLAB R2016b and later (Due to usage of MATLAB functions like "isstring").

  OBJ = FfmpegVideoWriter(FILENAME) constructs a FfmpegVideoWriter object to
  write video data to file using FFmpeg command line tool (see https://www.ffmpeg.org/).
  FILENAME is a character array or string that specifies the name of the file to create.
  The file format is determined by the extension of the file (.avi / .mkv / .mp4 and 
  any any other suitable container format supported by FFmpeg).

  The class interface is designed to resemble MATLAB built-in VideoWriter class.
  The main advantage of using the class over VideoWriter, is that FFmpeg,
  supports much much more formats, codes and many other options cooperated to VideoWriter.
  There are existing FFmpeg interfaces for MATLAB, but all the implementations I could
  find are, requires that all the input images be in memory before executing FFmpeg.
  The following class allows writing the video one frame at a time.
  Note: The class interface uses FFmpeg naming conventions when suited.

  The class default video codec is H.264 (AVC), with yuv420 pixel format, 30 fps and crf=17 quality.
  Natively supported codecs are H.264, H.265 and VP9, but any codec supported by FFmpeg may be used.
  
  The object uses FFmpeg command line tool for encoding the video.
  FFmpeg executable (ffmpeg.exe in case of Windows) must be present ("installed").
  Note: There is no official Windows installer for FFmpeg.
        You may follow the instructions in: https://www.wikihow.com/Install-FFmpeg-on-Windows
        The default executable path (in Windows) is assumed to be: C:\FFmpeg\bin\ffmpeg.exe
  The object executes FFmpeg as sub-process, and writes video frame to stdin pipe of FFmpeg.
  The object also reads FFmpeg logging (text) from stderr pipe of FFmpeg.
  Interfacing FFmpeg sub-process is based on JAVA code (within MATLAB).
   _____________             ___________                  ________ 
  | MATLAB      |           |           |                |        |
  | Array       |   stdin   | FFmpeg    |                | Output |
  | RGB (format)| --------> | process   | -------------> | file   |
  |_____________| raw frame |___________| encoded video  |________|
   
  Execution stages:
  1. Create FfmpegVideoWriter object.
     Example: v = FfmpegVideoWriter('output.mp4');
  2. Set object properties (in case defaults does not satisfy).
     Example: v.ffmpeg_cmd = 'c:\FFmpeg\bin\ffmpeg.exe';
              v.log_file = 'ffmpeg_log.txt';
              v.framerate = 25;
              v.pix_fmt = 'yuv444p';
              v.vcodec = 'libx265';
              v.crf = 18;
  3. Execute open method.
     Example: open(v);
  4. Execute writeFrame method for every video frame to be appended.
     Example: for i = 1:n_frames
                  I = zeros(height, width, 3, 'uint8');
                  I = insertText(I, [width/2 , height/2], num2str(i), 'FontSize', 160);
                  writeFrame(v, I);
              end
  5. Execute close method.
     Example: close(v);

Methods:
  open        - Make preparations for writing video data.
                Properties should not be modified after executing "open".
  close       - Close file after writing video data (close FFmpeg process).
  writeFrame  - Write single video frame.

Properties:
  ffmpeg_cmd      - FFmpeg executable file path.
  log_file        - LOG file name.
                    Empty - no log. char array - log file name. Numeric value 1 - print log to Command Window.
  output_filename - Name of the output video file to create.
  framerate       - Video playback frame rate (frames per second).
  pix_fmt         - Pixel format of the output video - applies formats supported by FFmpeg.
                    Example for supported formats: 'yuv420p', 'yuv444p'.
  vcodec          - Video codec - applies video codecs supported by FFmpeg.
                    Example: 'libx264', 'libx265', 'libvpx-vp9'.
  crf             - Constant Rate Factor, lower value applies higher quality of encoded video (and larger file size).
                    The value is depends on the encoder that is used (refer to FFmpeg documentation).
                    For using default crf, set crf to negative value.
                    Note: many video codecs have no support for crf parameter (set crf to -1 for these codecs).
  cmd             - Complete FFmpeg command line with arguments.
                    Setting cmd "manually" overrides all other settings.
                    Users may set cmd "manually" if they "know what they are doing".

Notes:
   1. The implementation was tested under Windows OS only (never tested in Linux or Mac).

   Author: Rotem (Year 2021).

# FfmpegVideoWriter
<p class="has-line-data" data-line-start="0" data-line-end="1">FfmpegVideoWriter Create a FFmpeg Video Writer object.</p>
<p class="has-line-data" data-line-start="2" data-line-end="3">Note: Requires MATLAB R2016b and later (Due to usage of MATLAB functions like “isstring”).</p>
<p class="has-line-data" data-line-start="4" data-line-end="9">OBJ = FfmpegVideoWriter(FILENAME) constructs a FfmpegVideoWriter object to<br>
write video data to file using FFmpeg command line tool (see <a href="https://www.ffmpeg.org/">https://www.ffmpeg.org/</a>).<br>
FILENAME is a character array or string that specifies the name of the file to create.<br>
The file format is determined by the extension of the file (.avi / .mkv / .mp4 and<br>
any any other suitable container format supported by FFmpeg).</p>
<p class="has-line-data" data-line-start="10" data-line-end="17">The class interface is designed to resemble MATLAB built-in VideoWriter class.<br>
The main advantage of using the class over VideoWriter, is that FFmpeg,<br>
supports much much more formats, codes and many other options cooperated to VideoWriter.<br>
There are existing FFmpeg interfaces for MATLAB, but all the implementations I could<br>
find are, requires that all the input images be in memory before executing FFmpeg.<br>
The following class allows writing the video one frame at a time.<br>
Note: The class interface uses FFmpeg naming conventions when suited.</p>
<p class="has-line-data" data-line-start="18" data-line-end="20">The class default video codec is H.264 (AVC), with yuv420 pixel format, 30 fps and crf=17 quality.<br>
Natively supported codecs are H.264, H.265 and VP9, but any codec supported by FFmpeg may be used.</p>
<p class="has-line-data" data-line-start="21" data-line-end="29">The object uses FFmpeg command line tool for encoding the video.<br>
FFmpeg executable (ffmpeg.exe in case of Windows) must be present (“installed”).<br>
Note: There is no official Windows installer for FFmpeg.<br>
You may follow the instructions in: <a href="https://www.wikihow.com/Install-FFmpeg-on-Windows">https://www.wikihow.com/Install-FFmpeg-on-Windows</a><br>
The default executable path (in Windows) is assumed to be: C:\FFmpeg\bin\ffmpeg.exe<br>
The object executes FFmpeg as sub-process, and writes video frame to stdin pipe of FFmpeg.<br>
The object also reads FFmpeg logging (text) from stderr pipe of FFmpeg.<br>
Interfacing FFmpeg sub-process is based on JAVA code (within MATLAB).</p>
<hr>
<br>
   _____________             ___________                  ________ <br>
  | MATLAB      |           |           |                |        |<br>
  | Array       |   stdin   | FFmpeg    |                | Output |<br>
  | RGB (format)| --------> | process   | -------------> | file   |<br>
  |_____________| raw frame |___________| encoded video  |________|<br>
<br>
<ol>
<li class="has-line-data" data-line-start="36" data-line-end="38">Create FfmpegVideoWriter object.<br>
Example: v = FfmpegVideoWriter(‘output.mp4’);</li>
<li class="has-line-data" data-line-start="38" data-line-end="45">Set object properties (in case defaults does not satisfy).<br>
Example: v.ffmpeg_cmd = ‘c:\FFmpeg\bin\ffmpeg.exe’;<br>
v.log_file = ‘ffmpeg_log.txt’;<br>
v.framerate = 25;<br>
v.pix_fmt = ‘yuv444p’;<br>
v.vcodec = ‘libx265’;<br>
v.crf = 18;</li>
<li class="has-line-data" data-line-start="45" data-line-end="47">Execute open method.<br>
Example: open(v);</li>
<li class="has-line-data" data-line-start="47" data-line-end="53">Execute writeFrame method for every video frame to be appended.<br>
Example: for i = 1:n_frames<br>
I = zeros(height, width, 3, ‘uint8’);<br>
I = insertText(I, [width/2 , height/2], num2str(i), ‘FontSize’, 160);<br>
writeFrame(v, I);<br>
end</li>
<li class="has-line-data" data-line-start="53" data-line-end="56">Execute close method.<br>
Example: close(v);</li>
</ol>
<p class="has-line-data" data-line-start="56" data-line-end="61">Methods:<br>
open        - Make preparations for writing video data.<br>
Properties should not be modified after executing “open”.<br>
close       - Close file after writing video data (close FFmpeg process).<br>
writeFrame  - Write single video frame.</p>
<p class="has-line-data" data-line-start="62" data-line-end="79">Properties:<br>
ffmpeg_cmd      - FFmpeg executable file path.<br>
log_file        - LOG file name.<br>
Empty - no log. char array - log file name. Numeric value 1 - print log to Command Window.<br>
output_filename - Name of the output video file to create.<br>
framerate       - Video playback frame rate (frames per second).<br>
pix_fmt         - Pixel format of the output video - applies formats supported by FFmpeg.<br>
Example for supported formats: ‘yuv420p’, ‘yuv444p’.<br>
vcodec          - Video codec - applies video codecs supported by FFmpeg.<br>
Example: ‘libx264’, ‘libx265’, ‘libvpx-vp9’.<br>
crf             - Constant Rate Factor, lower value applies higher quality of encoded video (and larger file size).<br>
The value is depends on the encoder that is used (refer to FFmpeg documentation).<br>
For using default crf, set crf to negative value.<br>
Note: many video codecs have no support for crf parameter (set crf to -1 for these codecs).<br>
cmd             - Complete FFmpeg command line with arguments.<br>
Setting cmd “manually” overrides all other settings.<br>
Users may set cmd “manually” if they “know what they are doing”.</p>
<p class="has-line-data" data-line-start="80" data-line-end="81">Notes:</p>
<ol>
<li class="has-line-data" data-line-start="81" data-line-end="83">The implementation was tested under Windows OS only (never tested in Linux or Mac).</li>
</ol>
<p class="has-line-data" data-line-start="83" data-line-end="84">Author: Rotem (Year 2021).</p>

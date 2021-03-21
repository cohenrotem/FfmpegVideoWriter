classdef FfmpegVideoWriter < dynamicprops
    %FfmpegVideoWriter Create a FFmpeg Video Writer object.
    %
    %   Note: Requires MATLAB R2016b and later (Due to usage of MATLAB functions like "isstring").
    %
    %   OBJ = FfmpegVideoWriter(FILENAME) constructs a FfmpegVideoWriter object to
    %   write video data to file using FFmpeg command line tool (see https://www.ffmpeg.org/).
    %   FILENAME is a character array or string that specifies the name of the file to create.
    %   The file format is determined by the extension of the file (.avi / .mkv / .mp4 and 
    %   any any other suitable container format supported by FFmpeg).
    %
    %   The class interface is designed to resemble MATLAB built-in VideoWriter class.
    %   The main advantage of using the class over VideoWriter, is that FFmpeg,
    %   supports much much more formats, codes and many other options cooperated to VideoWriter.
    %   There are existing FFmpeg interfaces for MATLAB, but all the implementations I could
    %   find are, requires that all the input images be in memory before executing FFmpeg.
    %   The following class allows writing the video one frame at a time.
    %   Note: The class interface uses FFmpeg naming conventions when suited.
    %
    %   The class default video codec is H.264 (AVC), with yuv420 pixel format, 30 fps and crf=17 quality.
    %   Natively supported codecs are H.264, H.265 and VP9, but any codec supported by FFmpeg may be used.
    %   
    %   The object uses FFmpeg command line tool for encoding the video.
    %   FFmpeg executable (ffmpeg.exe in case of Windows) must be present ("installed").
    %   Note: There is no official Windows installer for FFmpeg.
    %         You may follow the instructions in: https://www.wikihow.com/Install-FFmpeg-on-Windows
    %         The default executable path (in Windows) is assumed to be: C:\FFmpeg\bin\ffmpeg.exe
    %   The object executes FFmpeg as sub-process, and writes video frame to stdin pipe of FFmpeg.
    %   The object also reads FFmpeg logging (text) from stderr pipe of FFmpeg.
    %   Interfacing FFmpeg sub-process is based on JAVA code (within MATLAB).
    %    _____________             ___________                  ________ 
    %   | MATLAB      |           |           |                |        |
    %   | Array       |   stdin   | FFmpeg    |                | Output |
    %   | RGB (format)| --------> | process   | -------------> | file   |
    %   |_____________| raw frame |___________| encoded video  |________|
    %    
    %   Execution stages:
    %   1. Create FfmpegVideoWriter object.
    %      Example: v = FfmpegVideoWriter('output.mp4');
    %   2. Set object properties (in case defaults does not satisfy).
    %      Example: v.ffmpeg_cmd = 'c:\FFmpeg\bin\ffmpeg.exe';
    %               v.log_file = 'ffmpeg_log.txt';
    %               v.framerate = 25;
    %               v.pix_fmt = 'yuv444p';
    %               v.vcodec = 'libx265';
    %               v.crf = 18;
    %   3. Execute open method.
    %      Example: open(v);
    %   4. Execute writeFrame method for every video frame to be appended.
    %      Example: for i = 1:n_frames
    %                   I = zeros(height, width, 3, 'uint8');
    %                   I = insertText(I, [width/2 , height/2], num2str(i), 'FontSize', 160);
    %                   writeFrame(v, I);
    %               end
    %   5. Execute close method.
    %      Example: close(v);
    %
    % Methods:
    %   open        - Make preparations for writing video data.
    %                 Properties should not be modified after executing "open".
    %   close       - Close file after writing video data (close FFmpeg process).
    %   writeFrame  - Write single video frame.
    %
    % Properties:
    %   ffmpeg_cmd      - FFmpeg executable file path.
    %   log_file        - LOG file name.
    %                     Empty - no log. char array - log file name. Numeric value 1 - print log to Command Window.
    %   output_filename - Name of the output video file to create.
    %   framerate       - Video playback frame rate (frames per second).
    %   pix_fmt         - Pixel format of the output video - applies formats supported by FFmpeg.
    %                     Example for supported formats: 'yuv420p', 'yuv444p'.
    %   vcodec          - Video codec - applies video codecs supported by FFmpeg.
    %                     Example: 'libx264', 'libx265', 'libvpx-vp9'.
    %   crf             - Constant Rate Factor, lower value applies higher quality of encoded video (and larger file size).
    %                     The value is depends on the encoder that is used (refer to FFmpeg documentation).
    %                     For using default crf, set crf to negative value.
    %                     Note: many video codecs have no support for crf parameter (set crf to -1 for these codecs).
    %   cmd             - Complete FFmpeg command line with arguments.
    %                     Setting cmd "manually" overrides all other settings.
    %                     Users may set cmd "manually" if they "know what they are doing".
    %
    % Notes:
    %   1. The implementation was tested under Windows OS only (never tested in Linux or Mac).

    %   Author: Rotem (Year 2021).

    % Public properties
    % SetObservable - can define PreSet and PostSet listeners for the properties
    % AbortSet - MATLAB compares the current property value to the new value. If the new value is the same MATLAB does not Trigger PreSet and PostSet events
    properties (Access = public, SetObservable, AbortSet)
        ffmpeg_cmd              = []; % Where to find FFmpeg executable.
        log_file                = []; % Options: Empty - no log. char array - log file name. Numeric value 1 - print log to Command Window.
        output_filename         = ''; % Name of the output video file.
        framerate(1,1) double {mustBeReal, mustBeNonnegative} = 30; % Use Property Validation (default frame rate is 30fps).
        pix_fmt                 = 'yuv420p'; % Encoded pixel format (default is 'yuv420p', select 'yuv444p' for better quality).
        vcodec                  = 'libx264'; % Video encoder codec (default is 'libx264', see FFmpeg documentation for supported video encoders).
        crf(1,1) double {mustBeReal, mustBeInteger} = 17; % Use Property Validation (default crf is 17, applies high quality).
        cmd                     = ''; % Complete FFmpeg command line with arguments.
    end
    
    % Properties that correspond to app components
    properties (Access = protected)
        width                                       = 0;     % Holds video frame width (must be the same for all video frames).
        height                                      = 0;     % Holds video frame height (must be the same for all video frames).
        
        is_open                                     = false; % true if open method was executed (marks object state as "open").
        
        is_write_frame_called                       = false; % true after first execution of writeFrame method.
        was_cmd_fixed_before_writing_first_frame    = false; % true if user set cmd property before first execution of writeFrame.
        do_print_log_to_command_window              = true;  % true if FFmpeg logging text is printed to MATLAB command window.
        
        p                                           = [];    % Holds reference to executed FFmpeg sub-process (reference to JAVA object).
        p_stderr                                    = [];    % Holds reference to stderr FFmpeg pipe (reference to JAVA object).
        p_stdin                                     = [];    % Holds reference to stdin FFmpeg pipe (reference to JAVA object).
        
        f_log                                       = -1;    % Holds fileID of LOG file.
        
        prop_listener                               event.proplistener % Property listener object.
    end

    % Public methods
    methods (Access = public)

        % Construct
        function obj = FfmpegVideoWriter(filename)
            if nargin < 1
                % There is an option to set filename later.
                filename = [];
            end
            
            % Convert filename to char array
            if isstring(filename)
                filename = convertStringsToChars(filename);
            end
            
            obj.log_file = [];
                       
            if isunix
                obj.ffmpeg_cmd = '/usr/bin/ffmpeg'; % Never tested.
            else
                obj.ffmpeg_cmd = 'C:\FFmpeg\bin\ffmpeg.exe'; % Default location of ffmpeg.exe in Windows (C:\FFmpeg\bin\ is the recommended path).
            end
            
            obj.output_filename = filename;
            
            % Add Listener to Properties (the current Listener is used only for giving few warning messages).
            % Each time property value is modified, the listener callback function is executed.
            observable_properties = {'ffmpeg_cmd', 'log_file', 'output_filename', 'framerate', 'pix_fmt', 'vcodec', 'crf', 'cmd'};
            obj.prop_listener = addlistener(obj, observable_properties, 'PreSet', @FfmpegVideoWriter.handlePropEvents);
            obj.prop_listener.Enabled = 0; % Disable the listener - enable it only after "open" is executed.
            
            if nargout == 0
                clear obj
            end
        end
      

        % Code that executes before app deletion
        function delete(obj)
            close(obj);
        end
        
        
        function open(obj)
            % Disable listener at the begging of the function.
            obj.prop_listener.Enabled = 0;
            
            if length(obj) > 1
                error('OBJ must be a 1x1 FfmpegVideoWriter object.');
            end
            
            if obj.is_open
                % If open is called multiple times, there should be no effect.
                return;
            end
            
            if isstring(obj.log_file)
                tmp = obj.log_file; obj.log_file = []; obj.log_file = convertStringsToChars(tmp); % Support string objects.
            end
            
            if isequal(obj.log_file, 1)
                % Print log to MATLAB Command window if obj.log_file = 1 (unique case).
                obj.do_print_log_to_command_window = true;
            else
                obj.do_print_log_to_command_window = false;
            end
            
            if isstring(obj.ffmpeg_cmd)
                tmp = obj.ffmpeg_cmd; obj.ffmpeg_cmd = [];obj.ffmpeg_cmd = convertStringsToChars(tmp); % For some reason obj.ffmpeg_cmd = convertStringsToChars(obj.ffmpeg_cmd) is not working.
            end
            
            % Verify that FFmpeg executable exists (applies Windows only).
            % obj.ffmpeg_cmd is allowed to be:
            % 1. Full name include path, like: 'C:\FFmpeg\bin\ffmpeg.exe'
            % 2. Parenthesized full name and path like: '"c:\Program Files\ffmpeg\ffmpeg.exe"'
            % 3. 'ffmpeg' or 'ffmpeg.exe', when ffmpeg is in the system path.
            % If obj.cmd is fixed by the user, skip the test (obj.ffmpeg_cmd is not used in that case).
            if isempty(obj.cmd) && ispc
                ffmpeg_cmnd = obj.ffmpeg_cmd;

                if (ffmpeg_cmnd(1) == '"' && ffmpeg_cmnd(end) == '"')
                    % Remove parentheses (example '"c:\Program Files\ffmpeg\ffmpeg.exe"' be 'c:\Program Files\ffmpeg\ffmpeg.exe').
                    ffmpeg_cmnd = ffmpeg_cmnd(2:end-1);
                end
                
                [filepath, name, ext] = fileparts(ffmpeg_cmnd);
                
                if isempty(filepath)
                    [status, ~] = system(['where /Q ', ffmpeg_cmnd]);
                else
                    [status, ~] = system(['where /Q "', filepath, ':', [name, ext], '"']);
                end
                
                if (status ~= 0)
                    warning([obj.ffmpeg_cmd, ' can''t be found. Please set ffmpeg_cmd to full path of ffmpeg.exe']);
                end
            end
            
            % Mark object as "opened".
            obj.is_open = true;
            
            % Enable listener at the end of the function.
            obj.prop_listener.Enabled = 1;
        end
        
        
        function writeFrame(obj, I)
            % Write image I to stdin PIPE of FFmpeg.
            % The first execution of writeFrame executes FFmpeg process.
            % I should be an image in MATLAB representation (normally 3D uint8 matrix in RGB format).
            % If I is 2D matrix (gray-scale), I is converted to RGB.
            % If I is not uint8, I is converted to uint8.
            % Note: In case obj.cmd is "manually" set by the user, above conversions are skipped.
            %
            % Before writing I to the PIPE, elements are reordered from MATLAB column major format 
            % to C-like row major format (conversion syntax: I = permute(I, ndims(I):-1:1);).
                       
            % Disable listener at the beginning of the function.
            obj.prop_listener.Enabled = 0;           
            
            if length(obj) > 1
                error('OBJ must be a 1x1 FfmpegVideoWriter object.');
            end

            if ~obj.is_open
                close(obj);
                error('OBJ must be open before writing video.  Call open(obj) before calling writeFrame.');
            end
            
            if isempty(I)
                close(obj);
                error('I argument is empty.');
            end
            
            if (~obj.is_write_frame_called)
                if isempty(obj.cmd)
                    obj.was_cmd_fixed_before_writing_first_frame = false;
                else
                    % Mark that obj.cmd was fixed by the user - applied by advanced users.
                    obj.was_cmd_fixed_before_writing_first_frame = true;

                    % Keep obj.cmd (but convert it to char array in case it is a string object).
                    if isstring(obj.cmd)
                        tmp = obj.cmd; obj.cmd = []; obj.cmd = convertStringsToChars(tmp); % MATLAB bug???
                    end
                end                
            end

            if ~obj.was_cmd_fixed_before_writing_first_frame
                % Check validity of I and convert I to 3D matrix, only if was_cmd_fixed_before_writing_first_frame = false.
                % In case was_cmd_fixed_before_writing_first_frame = true, assume users are "advanced users" that know what they are doing.
                if isscalar(I) || (ndims(I) > 3)
                    close(obj);
                    error('I must 2D or 3D matrix.');
                end

                if ismatrix(I)
                    I = cat(3, I, I, I); % Convert I from gray-scale to RGB.
                end

                if ~isa(I, 'uint8')
                    I = im2uint8(I); % Convert I to uint8.
                end
                            
                if obj.is_write_frame_called
                    % Second frame and later - resolution must be the same as the resolution of the first frame.
                    if (size(I, 2) ~= obj.width) || (size(I, 1) ~= obj.height)
                        err_message = ['Frame must be ', num2str(obj.width), ' by ', num2str(obj.height)];
                        close(obj);
                        error(err_message);
                    end                    
                else
                    % Build obj.cmd (FFmpeg command line with arguments), only if obj.cmd is empty.
                    % If the user manually set obj.cmd, keep obj.cmd (assume the users are "advanced users" and know what they are doing).
                    obj.width = size(I, 2);
                    obj.height = size(I, 1);
                    
                    if isstring(obj.pix_fmt)
                        tmp = obj.pix_fmt; obj.pix_fmt = []; obj.pix_fmt = convertStringsToChars(tmp); % MATLAB bug???
                    end
                    
                    if isstring(obj.vcodec)
                        tmp = obj.vcodec; obj.vcodec = []; obj.vcodec = convertStringsToChars(tmp);
                    end                    

                    % https://ffmpeg.org/ffmpeg-bitstream-filters.html
                    if strfind(obj.vcodec, '265')
                        % Apply metadata to HEVC encoded stream regarding color format (don't trust the defaults).
                        bsf = ' -bsf:v hevc_metadata=video_format=5:video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 ';
                    elseif strfind(obj.vcodec, '264')
                        % Apply metadata to AVC encoded stream regarding color format (don't trust the defaults).
                        bsf = ' -bsf:v h264_metadata=video_format=5:video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 ';
                    elseif strfind(obj.vcodec, 'vp9')
                        % Apply metadata to VP9 encoded stream regarding color format (don't trust the defaults).
                        bsf = ' -bsf:v vp9_metadata=color_space=bt709:color_range=tv ';
                    else
                        % Don't use Bitstream Filter for other codecs (too many options).
                        bsf = ' ';
                    end
                    
                    if obj.crf < 0
                        crf_cmd = ' '; % Use default crf of the selected codec in case crf is negative.
                    else
                        crf_cmd = [' -crf ', num2str(obj.crf)];
                    end
                    
                    % Build FFmpeg command line with arguments.
                    % FFmpeg input PIPE is RAW images in RGB color format.
                    % FFmpeg output is encoded video file.
                    % Arguments list:
                    % -y                            Overwrite output file without asking.
                    % -video_size {width}x{height}  Input resolution width x height.
                    % -pixel_format rgb24           Input frame color format is RGB with 8 bits per color component.
                    % -f rawvideo                   Input format: raw video.
                    % -framerate {framerate}        Video frame rate.
                    % -color_primaries bt709        Color primes of the input applies BT.709 standard (applies sRGB).
                    % -color_trc bt709              Gamma curve of the input applies BT.709 standard (applies sRGB).
                    % -colorspace bt709             Color space of the input applies BT.709 standard (applies sRGB).
                    % -i pipe:                      FFmpeg input is a PIPE.
                    % -vcodec {vcodec}              Output video codec (specify video encoder).
                    % -pix_fmt {pix_fmt}            Pixel format of output video (common formats: yuv420p or yuv444p).
                    % -crf {crf}                    Constant Rate Factor (lower value for higher quality and larger output file).
                    % -dst_range 0                  Explicitly define output video as "Limited Range" (default range).
                    % -color_primaries bt709        Color primes of the output applies BT.709 standard.
                    % -color_trc bt709              Gamma curve of the output applies BT.709 standard.
                    % -colorspace bt709             Color space of the output applies BT.709 standard.
                    % -bsf:v {*_metadata}           Use Bitstream Filter for adding color format metadata.
                    %    video_format=5             Mark video stream format as "unspecified" (default).
                    %    video_full_range_flag=0    Mark video stream as "Limited Range" (default).
                    %    colour_primaries=1         Mark video stream color primaries as BT.709
                    %    transfer_characteristics=1 Mark video stream transfer characteristics as BT.709
                    %    matrix_coefficients=1      Mark video stream matrix coefficients as BT.709
                    % {output_filename}             Output file name.
                    obj.cmd = [obj.ffmpeg_cmd, ' -y -video_size ', num2str(obj.width),'x', num2str(obj.height), ...
                               ' -pixel_format rgb24 -f rawvideo -framerate ', num2str(obj.framerate), ...
                               ' -color_primaries bt709 -color_trc bt709 -colorspace bt709', ...
                               ' -i pipe:', ...
                               ' -vcodec ', obj.vcodec, ' -pix_fmt ', obj.pix_fmt ,crf_cmd, ...
                               ' -dst_range 0 -color_primaries bt709 -color_trc bt709 -colorspace bt709', ...
                               bsf, ...
                               obj.output_filename];
                end
            end

            if ~obj.is_write_frame_called
                % Open log file (only if obj.log_file is a char array).
                if isa(obj.log_file, 'char')
                    [obj.f_log, errmsg] = fopen(obj.log_file, 'w');

                    if obj.f_log < 0
                        warning(errmsg);
                        err_message = ['Can''t open log file: ', obj.log_file, ' for writing'];
                        close(obj);
                        error(err_message);
                    end

                    fprintf(obj.f_log, 'FFmpeg full command line with arguments:\n%s\n\n', obj.cmd);
                else
                    obj.f_log = -1;
                end

                % Execute FFmpeg process, get opened sdtin and stderr pipes (use JAVA).
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                try
                    % https://stackoverflow.com/questions/4112470/java-how-to-both-read-and-write-to-from-process-thru-pipe-stdin-stdout
                    obj.p = java.lang.Runtime.getRuntime().exec(obj.cmd); % Process p = Runtime.getRuntime().exec(cmd);

                    % Register process (registration is recommended for preventing "zombie processes").
                    FfmpegVideoWriter.registerFfmpegProcess(obj.cmd, obj.p);
                catch e
                    % https://www.mathworks.com/help/matlab/ref/matlab.exception.javaexception-class.html
                    e.message
                    if (isa(e,'matlab.exception.JavaException'))
                        ex = e.ExceptionObject;
                        assert(isjava(ex));
                        ex.printStackTrace;        
                    end

                    fprintf('\n');
                    err_message = ['FFmpeg executable must be placed in a specific folder: ', obj.ffmpeg_cmd];
                    close(obj);
                    error(err_message);
                end

                % Get reference to stderr stream.
                obj.p_stderr = java.io.DataInputStream(obj.p.getErrorStream());

                % Get reference to stdin stream.
                % https://stackoverflow.com/questions/11543227/android-write-byte-array-to-outputstreamwriter
                obj.p_stdin = java.io.DataOutputStream(obj.p.getOutputStream());
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            
            % Write frame to stdin
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Reorder elements from MATLAB column major format to "Normal" (C-like) row major format.
            I = permute(I, ndims(I):-1:1);
            
            try
                % Write raw video frame to input stream of FFmpeg sub-process.
                obj.p_stdin.write(I(:))
                obj.p_stdin.flush();
            catch e
                e.message
                if (isa(e,'matlab.exception.JavaException'))
                    ex = e.ExceptionObject;
                    assert(isjava(ex));
                    ex.printStackTrace;        
                end

                printf('\n');
                err_message = ['Please check FFmpeg command line arguments: ', obj.cmd];
                close(obj);
                error(err_message);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % https://stackoverflow.com/questions/13596138/bufferedreader-detecting-if-there-is-text-left-to-read
            p_stderr_bytes_available = obj.p_stderr.available();

            if (p_stderr_bytes_available > 0)
                % Read all the available bytes from stderr stream.
                out = FfmpegVideoWriter.read_BufferedInputStream(obj.p_stderr);

                if (obj.do_print_log_to_command_window)
                    if ispc
                        %https://www.mathworks.com/matlabcentral/answers/429327-how-to-erase-newline-character-from-string
                        out = regexprep(out, '[\n\r]+', '\n'); % Replace all '\n\r' with '\n'
                    end

                    % Display out in MATLAB Command Window.
                    disp(out);
                elseif (obj.f_log >= 0)
                    % Write stderr (report) to log file.
                    fwrite(obj.f_log, out);
                end
            end
            
            % Mark that writeFrame was executed at least once.
            obj.is_write_frame_called = true;
                       
            % Enable the property listener at the end of the function.
            obj.prop_listener.Enabled = 1;
        end
        
        
        function close(obj)
            % Close the object and close FFmpeg process.
            obj.prop_listener.delete
           
            if length(obj) > 1
                error('OBJ must be a 1x1 FfmpegVideoWriter object.');
            end                      
            
            if obj.f_log >= 0
                fclose(obj.f_log);
                obj.f_log = -1;
            end

            if ~isempty(obj.p_stderr)
                obj.p_stderr.close();
                obj.p_stderr = [];
            end
            
            if ~isempty(obj.p_stdin)
                obj.p_stdin.close();
                obj.p_stdin = [];
            end

            % Unregister process (registration is recommended for preventing "zombie processes").
            FfmpegVideoWriter.unregisterFfmpegProcess(obj.cmd);

            if ~isempty(obj.p)
                if ~verLessThan('matlab', '9.3') % R2017b (Java 8 is supported from MATLAB R2017b)
                    % https://stackoverflow.com/questions/808276/how-to-add-a-timeout-value-when-using-javas-runtime-exec
                    if ~obj.p.waitFor(10, java.util.concurrent.TimeUnit.SECONDS) % If you're using Java 8 or later you could simply use the new waitFor with timeout:
                        % timeout - destroy the process.
                        obj.p.destroy(); % Destroy process (just in case...). (consider using destroyForcibly instead).
                    end
                end
                
                obj.p = [];
            end
            
            obj.is_open                                     = false;
            obj.is_write_frame_called                       = false;
            obj.was_cmd_fixed_before_writing_first_frame    = false;
        end
        
    end
    
    
    % Static methods
    methods(Static, Access=protected)

        % Callback Function for Property Event
        function handlePropEvents(src, evnt)
            % Display a warning message.
            warning([src.Name, ' property is modified while FfmpegVideoWriter is "opened".']);
        end
       
        % https://www.mathworks.com/matlabcentral/answers/66227-syntax-for-call-to-java-library-function-with-byte-reference-parameter
        function out = read_BufferedInputStream(input_stream)
            % The simple JAVA syntax input_stream.read(byte[]) is not supported by MATLAB.
            % We need to use a reticulately complicated solution for reading byes from the stream...
            % The solution was posted by Benjamin Davis on 17 Feb 2020.
        
            num_available = input_stream.available();
            %short circuit out if none available
            %do not try to read, or it will block
            if num_available == 0
                out = '';
                return;
            end
            %save the reflection method object between calls
            persistent m_read
            if isempty(m_read)
                %build the reflection object
                %we are going to lookup BufferedInputStream.read(byte[], int, int)
                %using reflection API
                getMethod_args = javaArray('java.lang.Class',3);

                %this rather cryptic syntax is used for byte[]
                %since it is not possible to use java.lang.Byte[].TYPE
                %See:
                %https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html#jvms-4.3.2
                byteArrayName = '[B';

                %these are the vararg list to getMethod
                getMethod_args(1) = java.lang.Class.forName(byteArrayName);
                getMethod_args(2) = java.lang.Integer.TYPE;
                getMethod_args(3) = java.lang.Integer.TYPE;

                %use reflection to get the method object
                m_read = input_stream.getClass().getMethod('read', getMethod_args);
            end
            
            %save the current buffer size and array of arguments to read()
            persistent buf_size read_args
            if isempty(buf_size)
                MIN_SIZE = 1024; %you could set this to whatever you want
                %make the buffer large enough to eat all available characters in the
                %stream
                buf_size = max(MIN_SIZE, num_available);

                %Note that this will fail:
                %   read_args = javaArray('java.lang.Object', 3)
                %   read_args(1) = zeros(1,buf_size,'int8')
                %So we instead use an ArrayList which will then be converted to
                %Object[] for the call to invoke.
                read_args = java.util.ArrayList();
                %this will become a byte[] in the ArrayList
                read_args.add(zeros(1,buf_size,'int8'));
                %arg for read start offset
                read_args.add(int32(0));
                %arg for read length
                read_args.add(int32(buf_size));
            end
            
            %Update the buffer to be larger if the input stream content grows
            if num_available > buf_size
                buf_size = num_available;
                read_args.set(0, zeros(1,buf_size,'int8'));
                read_args.set(2, int32(buf_size));
            end
            
            %Here is the magic, when read_args is unpacked, the byte[] reference in the first
            %element is passed
            n_read = m_read.invoke(input_stream, read_args.toArray());
            %so now we can go back to the original ArrayList and read out the contents
            out = char(read_args.get(0));
            out = out(:)'; %make row vector
            out = out(1:n_read); %trim to indicated size
        end


        function registerFfmpegProcess(cmd, p)
            % Manage book keeping of FFmpeg processes for preventing "zombie processes".
            % All FFmpeg commands (cmd) are stored in a "global" Map container.
            % The key-value pair M(cmd) = p, are stored in groot appdata (using setappdata command).
            % Before storing, the function checks if the M(cmd) already exists, and destroy the old process if it does.
            % Note: groot data is used because it's persistent, and not deleted by "clear all" command.
            % Note: The "book keeping" is useful when debugging the class.

            persistent is_first_time

            if isempty(is_first_time)
                if isappdata(groot, 'FfmpegProcessMap')
                    M = getappdata(groot, 'FfmpegProcessMap');
                    keySet = keys(M);

                    % If first time, destroy all "zombie processes".
                    for i = 1:length(keySet)
                        key = keySet{i};
                        proc = M(key);
                        proc.destroy();
                        warning('Zombie FFmpeg process is destroyed');
                    end

                    rmappdata(groot, 'FfmpegProcessMap');
                end
                is_first_time = false;
            end

            if isappdata(groot, 'FfmpegProcessMap')
                M = getappdata(groot, 'FfmpegProcessMap');

                if isKey(M, cmd)
                    % If cmd is in the map - there is a "zombie processes" that needs to be destroyed.
                    proc = M(cmd);
                    proc.destroy();
                    warning('Zombie FFmpeg process is destroyed');
                    remove(M, cmd);
                    M(cmd) = p; % Replace value of p (M(cmd) value is the new p).
                end
            else
                % Build new map if not exist.
                M = containers.Map(cmd, p);
            end

            % Store map M in groot.
            setappdata(groot, 'FfmpegProcessMap', M);
        end


        function unregisterFfmpegProcess(cmd)
            % Unregister a process - function should be executed after FFmpeg process ends.
            
            if ~isappdata(groot, 'FfmpegProcessMap')
                %warning('unregisterFfmpegProcess is executed but process is not registered');
                return
            end

            M = getappdata(groot, 'FfmpegProcessMap');

            if ~isKey(M, cmd)
                %warning('unregisterFfmpegProcess is executed but process is not registered');
                return
            end

            % Remove key from the map.
            remove(M, cmd);

            if isempty(M)
                % Map is empty - remove it from groot.
                rmappdata(groot, 'FfmpegProcessMap');
            else
                % Store updated map in groot.
                setappdata(groot, 'FfmpegProcessMap', M);        
            end
        end
        
    end
    
end

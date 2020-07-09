import std.stdio;
import std.process;
import std.format;

import gio.Application: GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Window;
import gtk.Builder;
import gtk.Button;
import gtk.TextView;
import gtk.Widget;
import gdk.Event;

enum GDK_KEY {
  Return = 0xff0d,
  Escape = 0xff1b,
}

void main(string[] args) {
  args = args[1..$];

  auto app = new Application("info.alpha-kai-net.popruby", GApplicationFlags.FLAGS_NONE);

  app.addOnActivate((GioApplication gapp) {
      auto builder = new Builder();
      //builder.addFromFile("/home/alphakai/works/projects/popruby/popruby.glade");
      builder.addFromString(import("popruby.glade"));

      Window window = cast(Window)builder.getObject("window");
      TextView code_area = cast(TextView)builder.getObject("code_area");
      Button run_button  = cast(Button)builder.getObject("run_button");
      Button exit_button = cast(Button)builder.getObject("exit_button");

      auto exec_ruby_and_copy_result_into_clipboard = () {
          auto code = code_area.getBuffer.getText();
          writeln("code: ", code);
          import core.thread;

          auto th = new Thread(() {
            auto pipes = pipeProcess("ruby", Redirect.stdin | Redirect.stdout | Redirect.stderr);

            pipes.stdin.writeln(code);
            pipes.stdin.flush();
            pipes.stdin.close();
            if (!wait(pipes.pid)) {
              string output;
              {
                string line;
                while ((line = pipes.stdout.readln()) !is null) {
                  output ~= line;
                }
                import std.string : chomp;
                output = output.chomp;
              }

              pipes = pipeProcess(["/usr/bin/xsel", "--clipboard", "--input"], Redirect.stdin);
              pipes.stdin.write(output);
              pipes.stdin.flush();
              pipes.stdin.close();
              wait(pipes.pid);
              writeln("result is copied to clipboard");
            } else {
              code_area.getBuffer.setText("Given Code is Error: \n%s".format(code));
            }
          }).start;
      };

      window.addOnKeyPress((GdkEventKey *event, Widget _) {
          if (event.keyval == GDK_KEY.Return && event.state & ModifierType.SHIFT_MASK) {
            exec_ruby_and_copy_result_into_clipboard();
          }
          if (event.keyval == GDK_KEY.Escape) {
            gapp.quit();
          }
          return false;
      });

      if (run_button !is null) {
        run_button.addOnClicked((Button _) {
          exec_ruby_and_copy_result_into_clipboard();
        });
      } else {
        throw new Error("Failed to load component, run_button");
      }

      if (exit_button !is null) {
        exit_button.addOnClicked((Button _) {
          gapp.quit();
        });
      } else {
        throw new Error("Failed to load component, exit_button");
      }

      window.setApplication(app);
      window.showAll();
  });

  app.run(args);
}

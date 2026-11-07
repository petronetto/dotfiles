import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// GNOME has no command that reports the focused window, so publish its class in
// a file that the touchpad-momentum daemon reads.
export default class FocusedWindowClass extends Extension {
    enable() {
        const path = GLib.build_filenamev([GLib.get_user_runtime_dir(), 'focused-window-class']);
        this._file = Gio.File.new_for_path(path);
        this._focusId = global.display.connect('notify::focus-window', () => this._publish());
        this._publish();
    }

    disable() {
        global.display.disconnect(this._focusId);
        this._focusId = null;
        try {
            this._file.delete(null);
        } catch (error) {
            // The file may already be gone.
        }
        this._file = null;
    }

    _publish() {
        const focused = global.display.focus_window;
        const windowClass = focused?.get_wm_class() ?? '';
        const contents = new TextEncoder().encode(`${windowClass}\n`);
        this._file.replace_contents(contents, null, false, Gio.FileCreateFlags.NONE, null);
    }
}

import { Workspaces } from './Workspaces.js';

const Clock = () => Widget.Label({
    className: 'clock',
    setup: self => self.poll(1000, self => {
        self.label = Utils.exec('date "+%H:%M:%S"');
    }),
});

export const Bar = (monitor = 0) => Widget.Window({
    name: `bar-${monitor}`,
    monitor,
    anchor: ['top', 'left', 'right'],
    exclusivity: 'exclusive',
    child: Widget.CenterBox({
        startWidget: Workspaces(),
        centerWidget: Widget.Label('NixOS + Hyprland'),
        endWidget: Clock(),
    }),
});
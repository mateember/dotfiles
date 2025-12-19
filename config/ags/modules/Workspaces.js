const hyprland = await Service.import('hyprland');

export const Workspaces = () => Widget.Box({
    className: 'workspaces',
    children: hyprland.bind('workspaces').as(ws => 
        ws.map(({ id }) => Widget.Button({
            onClicked: () => hyprland.messageAsync(`dispatch workspace ${id}`),
            child: Widget.Label(`${id}`),
            className: hyprland.active.workspace.bind('id')
                .as(i => i === id ? 'focused' : ''),
        }))
    ),
});
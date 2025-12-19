import { Bar } from './modules/Bar.js';

App.config({
    style: './style.css',
    windows: [
        Bar(0), // Create a bar for monitor 0
    ],
});
XClickThrough
=============
By default, OS X disables "click through" on application elements.  This means that if an application is in the background,
you have to click it once to give it focus, and again to make it do something.

This behavior is really annoying on multi-monitor setups, because you can _see_ the thing you want to click on, but you
have to double-click it to make something happen.

XClickThrough skirts around this problem by:

1. Capturing all mouse clicks
2. Finding the window being clicked
3. Setting that window as "front most" via the Accessibility API
4. Generating another click on the same spot

This means you can have a browser on one window, and an email client in the other, and you don't have to constantly
be double-clicking to get stuff done.

Beware that I wrote this entirely for myself, so I've only been testing it on my own machine (10.8.5). No guarantees it'll
work anywhere else, but it uses the older Carbon APIs for event taps and accessibility, so hopefully the backwards
compatibility goes pretty deep.

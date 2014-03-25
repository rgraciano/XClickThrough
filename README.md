XClickThrough
=============
UPDATE: I was playing with this to learn some Obj-C, and have since stopped maintaining it. OS X resists this feature in every way possible and I've had my fun, but if you want to pick it up, shoot me an email and I'm happy to answer questions.


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

XClickThrough works fine out of the box on 10.8.5. On Mavericks, you'll also need to give it permission in the new
[Accessibility Security & Privacy settings](http://www.cultofmac.com/236709/enable-access-for-assistive-devices-in-mavericks-os-x-tips/).

  

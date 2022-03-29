//
//  INAppStoreWindow.m
//
//  Copyright 2011 Indragie Karunaratne. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SBWindow.h"

/** -----------------------------------------
- There are 2 sets of colors, one for an active (key) state and one for an inactivate state
- Each set contains 3 colors. 2 colors for the start and end of the title gradient, and another color to draw the separator line on the bottom
- These colors are meant to mimic the color of the default titlebar (taken from OS X 10.6), but are subject
 to change at any time
 ----------------------------------------- **/

#define COLOR_KEY_START [NSColor colorWithDeviceRed:0.659 green:0.659 blue:0.659 alpha:1.00]
#define COLOR_KEY_END [NSColor colorWithDeviceRed:0.812 green:0.812 blue:0.812 alpha:1.00]
#define COLOR_KEY_BOTTOM [NSColor colorWithDeviceRed:0.318 green:0.318 blue:0.318 alpha:1.00]
 
#define COLOR_NOTKEY_START [NSColor colorWithDeviceRed:0.851 green:0.851 blue:0.851 alpha:1.00]
#define COLOR_NOTKEY_END [NSColor colorWithDeviceRed:0.929 green:0.929 blue:0.929 alpha:1.00]
#define COLOR_NOTKEY_BOTTOM [NSColor colorWithDeviceRed:0.600 green:0.600 blue:0.600 alpha:1.00]

/** Corner clipping radius **/
#define CORNER_CLIP_RADIUS 4.0

@interface SBWindow ()
- (void)_doInitialWindowSetup;
- (void)_createTitlebarView;
- (void)_recalculateFrameForTitleBarView;
- (void)_layoutTrafficLightsAndContent;
- (float)_minimumTitlebarHeight;
@end

@implementation SBTitlebarView


@end

@implementation SBWindow

#pragma mark -
#pragma mark Initialization

- (id)init
{
    if ((self = [super init])) {
        [self _doInitialWindowSetup];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self _doInitialWindowSetup];
}

#pragma mark -
#pragma mark Accessors

- (void)setTitleBarView:(NSView *)newTitleBarView
{
    if ((_titleBarView != newTitleBarView) && newTitleBarView) {
        _titleBarView = newTitleBarView;
    }
}

- (NSView*)titleBarView
{
    return _titleBarView;
}

        
#pragma mark -
#pragma mark Private

- (void)_doInitialWindowSetup
{
}

- (void)_layoutTrafficLightsAndContent
{
}

- (void)_createTitlebarView
{
}

- (void)_recalculateFrameForTitleBarView
{
}

- (float)_minimumTitlebarHeight
{
}
@end

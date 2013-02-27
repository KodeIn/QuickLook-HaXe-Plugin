/*
 ProcessingQLGenerator.m
 
 Processing Quick Look plugin
 Copyright (C) kroko
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
 Modifications by Jérémie Fery for HaXe source code.
 I don't understand well GNU so just do what the source code designer (krokro)
 say! xD
 */

#import "ProcessingQLGenerator.h"

@implementation ProcessingQLGenerator

- (id) initWithContentsOfURL:(NSURL *)url
{
	if ( self = [super init] )
    {
		NSError *error;
		NSStringEncoding sketchContentsEnc; // a place where encoding to interpret sketch data (string) is stored
		// Since Processing version 1040 sketches are UTF-8
		// We could use
		// sketchContentsStr = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error])
		// but who nows...
		if(!(sketchContentsStr = [NSString stringWithContentsOfURL:url usedEncoding:&sketchContentsEnc error:&error]))
		{
			NSLog(@"ProcessingQLGenerator. Error reading file %@. Tried using encoding %d. Reason: %@", [url path], sketchContentsEnc, [error localizedFailureReason]);
			[self release];
			return nil;
		}
		
		// else both url and sketchContentsStr exist
		sketchContentsStr = [sketchContentsStr stringByAppendingString:@"\n"]; // add an extra line to the end as that makes easer to scan the string
		sketchUrl = (NSURL *)url; // keep reference
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

/*	===============================================================
	PREVIEW
	=============================================================== */

// Return dictionary that contains custom display name
- (NSDictionary *) previewProperties
{
	NSString *sketchName = [[[sketchUrl path] stringByDeletingPathExtension] lastPathComponent];	
	NSString *dirName = [[[sketchUrl path] stringByDeletingLastPathComponent] lastPathComponent];
	// If sketch name != directory name it resides, then additional shetch resource has been called.
	// In that case set up custom display name adding " - <sketch name>" 
	if (![sketchName isEqualToString:dirName]) {
		sketchName = [NSString stringWithFormat:@"%@ - %@",sketchName,dirName];
	}
	return [NSDictionary dictionaryWithObjectsAndKeys:sketchName, (NSString *)kQLPreviewPropertyDisplayNameKey, nil ];
}

// Return prieview data
- (NSData *) previewData
{
	// Get reference to syntax colorised attributed string
	NSAttributedString *sketchContentsAtrStr = [self colorise];
	// Return it without last newline
	return [sketchContentsAtrStr RTFFromRange:NSMakeRange(0,[sketchContentsAtrStr length]-1) documentAttributes:nil];
}


/*	===============================================================
	THUMBNAIL
	=============================================================== */

- (NSSize)thumbnailSize {
	return NSMakeSize(thumbnailWidth, thumbnailHeight);
}

- (NSDictionary *) thumbnailProperties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:@"kUTTypeTIFF", (NSString *)kCGImageSourceTypeIdentifierHint, nil ];	
}

- (void) drawThumbnailInContext:(NSGraphicsContext *)context
{
	NSSize thumbnailSize = [self thumbnailSize];
    NSRect thumbnailRect = NSMakeRect(0.0, 0.0, thumbnailSize.width, thumbnailSize.height);
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:context];
	[context setShouldAntialias:YES];
	[[NSColor colorWithDeviceRed:33.0/255.0
						   green:33.0/255.0
							blue:33.0/255.0
						   alpha:1.0] set];
	NSRectFill(thumbnailRect);
	[[self colorise] drawInRect:thumbnailRect];
	[NSGraphicsContext restoreGraphicsState];
	[context setShouldAntialias:YES];
}



- (CGImageRef) thumbnailCgImage
{
	NSSize thumbnailSize = [self thumbnailSize];
	NSRect thumbnailRect = NSMakeRect(0.0, 0.0, thumbnailSize.width, thumbnailSize.height);
	CGContextRef cgContext = CGBitmapContextCreate(NULL, thumbnailSize.width, thumbnailSize.height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
	NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsContext];
	[[NSColor colorWithDeviceRed:33.0/255.0
						   green:33.0/255.0
							blue:33.0/255.0
						   alpha:1.0] set];
	NSRectFill(thumbnailRect);
	[[self colorise] drawInRect:thumbnailRect];
	[NSGraphicsContext restoreGraphicsState];
	CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
	CGContextRelease(cgContext);
	return cgImage;
}


/*
- (NSData *) thumbnailData
{
	NSSize thumbnailSize = [self thumbnailSize];
	NSRect thumbnailRect = NSMakeRect(0.0, 0.0, thumbnailSize.width, thumbnailSize.height);
	NSImage *thumbnailImage = [[[NSImage alloc] initWithSize:NSMakeSize(thumbnailSize.width, thumbnailSize.height)] autorelease];
	[thumbnailImage lockFocus];
 [[NSColor colorWithCalibratedRed:33.0/255.0
 green:33.0/255.0
 blue:33.0/255.0
 alpha:1.0] set];
	NSRectFill(thumbnailRect);
	[[self colorise] drawInRect:thumbnailRect];
	[thumbnailImage unlockFocus];
	return [thumbnailImage TIFFRepresentation];
}
*/


/*	===============================================================
	COLORISE
	=============================================================== */

- (NSAttributedString *) colorise
{
	// Create an attributed string from sketchContentsStr and set up default PDE font and size
	NSMutableAttributedString *pdeAttributedString = [[[NSMutableAttributedString alloc] 
													   initWithString:sketchContentsStr 
													   attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																   [NSFont fontWithName:@"Monaco" size:10], NSFontAttributeName, 
																   [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0], NSForegroundColorAttributeName, 
																   nil]
													   ] autorelease];
	// Array containing all words to be colorised in "pink" orange
	NSArray *orangeArray = [NSArray arrayWithObjects: 
							@"+", @"-", @"/", @"*", @"=", @"<", @">", @"&", @"|", @"^", @"!",
							
							@"public", @"private", @"override", @"static", @"inline", @"extern", @"dynamic",
							
							@"if", @"else", @"while", @"do", @"for", @"in", @"break", @"continue", @"return", @"switch", @"case", @"try", @"catch", @"throw", @"trace", @"new", @"this", @"super", @"untyped", @"cast", @"callback", @"here",
							
							@"extends", @"function", @"var",
							nil];
	
		// Array containing all words to be colorised in blue
	NSArray *blueArray = [NSArray arrayWithObjects:
						  @"Float", @"Int", @"import", @"Sprite", @"Event", @"Array", @"String", @"Bool", @"Void", @"enum",  nil];
	
	NSArray *mauveArray = [NSArray arrayWithObjects:
						  @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0", @"true",
						   @"false", @"null", nil];
	
	// The actual color
	NSColor *orangeColor = [NSColor colorWithCalibratedRed:249.0/255.0
													 green:38.0/255.0
													  blue:114.0/255.0
													 alpha:1.0]; // #F92672
	
	
	// The actual color
	NSColor *blueColor = [NSColor colorWithCalibratedRed:102.0/255.0
												   green:217.0/255.0
													blue:239.0/255.0
												   alpha:1.0]; // #66D9EF
	
	NSColor *mauveColor = [NSColor colorWithCalibratedRed:174.0/255.0
													green:129.0/255.0
													 blue:255.0/255.0
													alpha:1.0]; // #AE81FF
	
	NSColor *greenColor = [NSColor colorWithCalibratedRed:166.0/255.0
													green:226.0/255.0
													 blue:46.0/255.0
													alpha:1.0]; // #66D9EF
	
	NSColor *yellowColor = [NSColor colorWithCalibratedRed:230.0/255.0
													 green:219.0/255.0
													  blue:116.0/255.0
													 alpha:1.0]; // #E6DB74
	
	// Gray color for comments
	NSColor *commentColor = [NSColor colorWithCalibratedRed:117.0/255.0
													  green:113.0/255.0
													   blue:94.0/255.0
													  alpha:1.0]; // #75715E
	
	// Load it up
	NSDictionary *specialWordDict = [NSDictionary dictionaryWithObjectsAndKeys:
									 orangeArray, orangeColor,
									 blueArray, blueColor,
									 mauveArray, mauveColor,
									 nil];
	
	// Character set that covers all chars a variable can have
	NSMutableCharacterSet *myCharSet = [NSMutableCharacterSet alphanumericCharacterSet];
	[myCharSet addCharactersInString:@"_"];
	
	// Scanner
	NSScanner *colourScanner = [NSScanner scannerWithString:sketchContentsStr];
	[colourScanner setCaseSensitive:YES];
	
	// WORD COLORISING
	
	NSEnumerator *myKeyEnumerator = [specialWordDict keyEnumerator];
	// Current color we look at
	NSColor *keyColour;
	while ((keyColour = [myKeyEnumerator nextObject]))
	{		
		NSEnumerator * myArrayEnumerator = [[specialWordDict objectForKey:keyColour] objectEnumerator];
		// Current word in color we look at
		NSString *specialWord;
		while (specialWord = [myArrayEnumerator nextObject])
		{
			//NSScanner *colourScanner = [NSScanner scannerWithString:sketchContentsStr];
			//[colourScanner setCaseSensitive:YES];
			
			// Go to beginning in string
			[colourScanner setScanLocation:0];
			while (![colourScanner isAtEnd])
			{
				[colourScanner scanUpToString:specialWord intoString:nil]; // scan up to the special word that needs colour
				if (![colourScanner isAtEnd]) // if scanner at this point is not at end (or characters from the set to be skipped remaining != TRUE), we have found a word
				{
					if ([colourScanner scanLocation] == 0 && 
						![myCharSet characterIsMember:[sketchContentsStr characterAtIndex:([colourScanner scanLocation]+[specialWord length])]]
						)  //if special word is at the very beginning of pde and is not followed by char then colorise
					{
						[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:keyColour range:NSMakeRange([colourScanner scanLocation], [specialWord length])];
					}
					else if( ![myCharSet characterIsMember:[sketchContentsStr characterAtIndex:([colourScanner scanLocation]-1)]] &&
							![myCharSet characterIsMember:[sketchContentsStr characterAtIndex:([colourScanner scanLocation]+[specialWord length])]]
							) //if special word is somewhere in pde and is not lead and followed by char then colorise
					{
						[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:keyColour range:NSMakeRange([colourScanner scanLocation], [specialWord length])];
					}
					// else do not colorise
					[colourScanner setScanLocation:[colourScanner scanLocation]+[specialWord length]];
				}
			}
		}	
	}
	
	// COMMENT COLORISING
	
	// Set up array that will contain ranges where comments are in the string
	NSMutableArray *commentsRanges = [NSMutableArray array];
	
	// Reset scanner
	[colourScanner setCharactersToBeSkipped:nil];
	[colourScanner setScanLocation:0];
	
	while (![colourScanner isAtEnd]) {
		[colourScanner scanUpToString:@"//" intoString:nil];
		if (![colourScanner isAtEnd]) // found comment
		{
			NSString *comment;
			[colourScanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&comment];
			[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:commentColor range:NSMakeRange([colourScanner scanLocation]-[comment length],[comment length])];
			[commentsRanges addObject:[NSValue valueWithRange:NSMakeRange([colourScanner scanLocation]-[comment length],[comment length])]];
		}
	}
	[colourScanner setScanLocation:0];
	while (![colourScanner isAtEnd]) {
		[colourScanner scanUpToString:@"/*" intoString:nil];
		if (![colourScanner isAtEnd])
		{
			[colourScanner setScanLocation:([colourScanner scanLocation]+2)];
			NSString *comment;
			[colourScanner scanUpToString:@"*/" intoString:&comment];
			if([colourScanner isAtEnd]) // in case of unclosed multiline coment (syntax error)
			{
				[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:commentColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+2),[comment length]+2)];
				[commentsRanges addObject: [NSValue valueWithRange:NSMakeRange([colourScanner scanLocation]-([comment length]+2),[comment length]+2)]];
				break;
			}
			[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:commentColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+2),[comment length]+4)];
			[commentsRanges addObject: [NSValue valueWithRange:NSMakeRange([colourScanner scanLocation]-([comment length]+2),[comment length]+4)]];
			// skip over as to avoid */* to be taken as end AND beginning of a comment
			[colourScanner setScanLocation:([colourScanner scanLocation]+2)];
		}		
	}
	
	
	// STRING COLORISING
	
	// Reset scanner
	[colourScanner setScanLocation:0];
	BOOL isWithinComments = FALSE;
	while (![colourScanner isAtEnd]) {
		[colourScanner scanUpToString:@"\"" intoString:nil];
		if (![colourScanner isAtEnd])
		{
			isWithinComments = FALSE;
			for (unsigned int i=0;i<[commentsRanges count];i++) // check whether we aren't within a comment
			{
				if (NSLocationInRange([colourScanner scanLocation],[[commentsRanges objectAtIndex:i] rangeValue]))
				{
						// if we are step to the end
					[colourScanner setScanLocation:([[commentsRanges objectAtIndex:i] rangeValue].location+[[commentsRanges objectAtIndex:i] rangeValue].length)];
					isWithinComments = TRUE;
					break;
				}
			}
			if (isWithinComments) continue;
			[colourScanner setScanLocation:([colourScanner scanLocation]+1)];
			NSString *comment;
			[colourScanner scanUpToString:@"\"" intoString:&comment];
				// spec case
			if([colourScanner isAtEnd])
			{
				[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:yellowColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+1),[comment length]+1)];
				break;
			}
			[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:yellowColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+1),[comment length]+2)];
			[colourScanner setScanLocation:([colourScanner scanLocation]+1)];
		}
	}
	return pdeAttributedString;
	[colourScanner setScanLocation:0];
	while (![colourScanner isAtEnd]) {
		[colourScanner scanUpToString:@"'" intoString:nil];
		if (![colourScanner isAtEnd])
		{
			BOOL isWithinComments = FALSE;
			for (unsigned int i=0;i<[commentsRanges count];i++) // check whether we aren't within a comment
			{				
				if (NSLocationInRange([colourScanner scanLocation],[[commentsRanges objectAtIndex:i] rangeValue]))
				{
					//[colourScanner setScanLocation:([colourScanner scanLocation]+1)];
					[colourScanner setScanLocation:([[commentsRanges objectAtIndex:i] rangeValue].location+[[commentsRanges objectAtIndex:i] rangeValue].length)];
					isWithinComments = TRUE;
					break;
				}
			}
			if (isWithinComments) continue;
			[colourScanner setScanLocation:([colourScanner scanLocation]+1)];
			NSString *comment;
			[colourScanner scanUpToString:@"'" intoString:&comment];
			// spec case
			if([colourScanner isAtEnd])
			{
				[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:yellowColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+1),[comment length]+1)];
				break;
			}
			[pdeAttributedString addAttribute:NSForegroundColorAttributeName value:yellowColor range:NSMakeRange([colourScanner scanLocation]-([comment length]+1),[comment length]+2)];
			[colourScanner setScanLocation:([colourScanner scanLocation]+1)];
		}		
	}
	
}


@end
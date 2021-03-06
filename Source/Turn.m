//
//  Turn.m
//  YourMove
//
//  Created by Jens Alfke on 7/3/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "Turn.h"
#import "Game+Protected.h"
#import "Player.h"


NSString* const kTurnCompleteNotification = @"TurnComplete";


@interface Turn ()
- (instancetype) init NS_DESIGNATED_INITIALIZER;
@property (copy) NSString *move, *boardState;
@property (retain) NSDate *date;
@end



@implementation Turn

- (instancetype) init {
    return [super init];
}

- (instancetype) initWithPlayer: (Player*)player
{
    NSParameterAssert(player!=nil);
    self = [super init];
    if (self != nil) {
        _game = player.game;
        _player = player;
        _status = kTurnEmpty;
        self.boardState = _game.latestTurn.boardState;
    }
    return self;
}

- (instancetype) initStartOfGame: (Game*)game
{
    NSParameterAssert(game!=nil);
    self = [super init];
    if (self != nil) {
        _game = game;
        _status = kTurnFinished;
        self.boardState = game.initialStateString;
        self.date = [NSDate date];
    }
    return self;
}


- (instancetype) initWithCoder: (NSCoder*)decoder
{
    self = [self init];
    if( self ) {
        _game =        [decoder decodeObjectForKey: @"game"];
        _player =      [decoder decodeObjectForKey: @"player"];
        _status =      [decoder decodeIntForKey: @"status"];
        _move =       [[decoder decodeObjectForKey: @"move"] copy];
        _boardState = [[decoder decodeObjectForKey: @"boardState"] copy];
        _date =       [[decoder decodeObjectForKey: @"date"] copy];
        _comment =    [[decoder decodeObjectForKey: @"comment"] copy];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
    [coder encodeObject: _game       forKey: @"game"];
    [coder encodeObject: _player     forKey: @"player"];
    [coder encodeInt:    _status     forKey: @"status"];
    [coder encodeObject: _move       forKey: @"move"];
    [coder encodeObject: _boardState forKey: @"boardState"];
    [coder encodeObject: _date       forKey: @"date"];
    [coder encodeObject: _comment    forKey: @"comment"];
}

- (void) dealloc
{
    [_move release];
    [_boardState release];
    [_date release];
    [_comment release];
    [super dealloc];
}


- (NSString*) description
{
    return [NSString stringWithFormat: @"%@[%@, #%ld, %@]", self.class, _game.class, (unsigned long)self.turnNumber, _move];
}


@synthesize game=_game, player=_player, move=_move, boardState=_boardState, date=_date, comment=_comment,
            replaying=_replaying;


- (NSUInteger) turnNumber { return [_game.turns indexOfObjectIdenticalTo: self]; }
- (BOOL) isLatestTurn { return _game.turns.lastObject == self; }
- (Player*) nextPlayer { return _player ? _player.nextPlayer : (_game.players)[0]; }
- (TurnStatus) status { return _status; }

- (void) setStatus: (TurnStatus)status
{
    BOOL ok = NO;
    switch( _status ) {
        case kTurnEmpty:
            ok = (status==kTurnPartial) || (status==kTurnComplete);
            break;
        case kTurnPartial:
            ok = (status==kTurnEmpty) || (status==kTurnComplete) || (status==kTurnFinished);
            break;
        case kTurnComplete:
            ok = (status==kTurnEmpty) || (status==kTurnPartial) || (status==kTurnFinished);
            break;
        case kTurnFinished:
            break;
    }
    NSAssert2(ok,@"Illegal Turn status transition %i -> %i", _status,status);
    
    [self captureBoardState];
    _status = status;
    if( _status==kTurnEmpty ) {
        self.move = nil;
        self.date = nil;
    } else
        self.date = [NSDate date];
}


- (void) _unfinish
{
    NSAssert(_status==kTurnFinished,@"Turn must be finished");
    [self willChangeValueForKey: @"status"];
    _status = kTurnComplete;
    [self didChangeValueForKey: @"status"];
}


- (Turn*) previousTurn
{
    NSUInteger n = self.turnNumber;
    if( n > 0 )
        return (_game.turns)[n-1];
    else
        return nil;
}

- (Turn*) nextTurn
{
    NSUInteger n = self.turnNumber;
    if( n+1 < _game.turns.count )
        return (_game.turns)[n+1];
    else
        return nil;
}


- (void) addToMove: (NSString*)move
{
    if( ! _replaying ) {
        NSParameterAssert(move.length);
        NSAssert(_status<kTurnComplete,@"Complete Turn can't be modified");
        if( _move )
            move = [_move stringByAppendingString: move];
        self.move = move;
        [self captureBoardState];
        self.date = [NSDate date];
        if( _status==kTurnEmpty )
            self.status = kTurnPartial;
    }
}


- (void) captureBoardState
{
    if( ! _replaying ) {
        NSAssert(_status<kTurnFinished,@"Finished Turn can't be modified");
        if( _game.table )
            self.boardState = _game.stateString;
    }
}


@end

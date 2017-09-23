#ifndef MEGAHAL_H
#define MEGAHAL_H 1

/*===========================================================================*/

/*
 *  Copyright (C) 1998 Jason Hutchens
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation; either version 2 of the license or (at your option)
 *  any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 *  or FITNESS FOR A PARTICULAR PURPOSE.  See the Gnu Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  675 Mass Ave, Cambridge, MA 02139, USA.
 */

/*===========================================================================*/

/*
 *		$Id: megahal.h,v 1.8 2004/02/25 20:19:39 lfousse Exp $
 *
 *		File:			megahal.h
 *
 *		Program:		MegaHAL
 *
 *		Purpose:		To simulate a natural language conversation with a psychotic
 *						computer.  This is achieved by learning from the user's
 *						input using a third-order Markov model on the word level.
 *						Words are considered to be sequences of characters separated
 *						by whitespace and punctuation.  Replies are generated
 *						randomly based on a keyword, and they are scored using
 *						measures of surprise.
 *
 *		Author:		Mr. Jason L. Hutchens
 *
 *		WWW:			http://megahal.sourceforge.net
 *
 *		E-Mail:		hutch@ciips.ee.uwa.edu.au
 *
 *		Contact:		The Centre for Intelligent Information Processing Systems
 *						Department of Electrical and Electronic Engineering
 *						The University of Western Australia
 *						AUSTRALIA 6907
 *
 */

/*===========================================================================*/

#ifdef SUNOS
extern double drand48(void);
extern void srand48(long);
#endif

/* public functions  */

void megahal_setnoprompt (void);
void megahal_setnowrap (void);
void megahal_setnobanner (void);

void megahal_seterrorfile(char *filename);
void megahal_setstatusfile(char *filename);
void megahal_setdirectory (char *dir);

void megahal_initialize(void);

char *megahal_initial_greeting(void);

int megahal_command(char *input);

char *megahal_do_reply(char *input, int log);
void megahal_learn_no_reply(char *input, int log);
void megahal_output(char *output);
char *megahal_input(char *prompt);

void megahal_cleanup(void);

#endif /* MEGAHAL_H  */

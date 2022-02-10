#
# TraceDlg
# -----------------------------------------------------------------
# Implements the Tracepoint configuration dialog box. This (modal)
# dialog will be called upon to interact with gdb's tracepoint routines
# allowing the user to add/edit tracepoints. Specifically, user can
# specify:
#
#    - What data to collect: locals, registers, "all registers", "all locals",
#                            user-defined (globals)
#    - Number of passes which we should collect the data
#    - An ignore count after which data will start being collected
# This method will destroy itself when the dialog is released. It returns
# either one if a tracepoint was set/edited successfully or zero if 
# the user bails out (cancel or destroy buttons).

itcl_class TraceDlg {
  # ------------------------------------------------------------------
  # CONSTRUCTOR: create new trace dialog
  # ------------------------------------------------------------------
  constructor {config} {
    #
    #  Create a window with the same name as this object
    #
    set class [$this info class]
    @@rename $this $this-tmp-
    @@frame $this -class $class 
    @@rename $this $this-win-
    @@rename $this-tmp- $this
    
    set top [winfo toplevel $this]
    wm withdraw $top
    build_win $this
    after idle [list wm deiconify $top]
    after idle [list $this title]
#    after idle grab $this
  }

  # ------------------------------------------------------------------
  #  DESTRUCTOR - destroy window containing widget
  # ------------------------------------------------------------------
  destructor {

    # Remove this window and all hooks
#    grab release $this
    if {$ActionsDlg != ""} {
      catch {manage delete $ActionsDlg}
    }
    set top [winfo toplevel $this]
    destroy $top
    destroy $this
  }

  # ------------------------------------------------------------------
  # METHOD: build_win - build the Trace dialog box (cache this?)
  # ------------------------------------------------------------------
  method build_win {f} {
    global _TPassCount


    # Need to set the title to either "Add Tracepoint" or "Edit Tracepoint",
    # depending on the location of the given tracepoint.
    # !! Why can I not do this?

    # If we have multiple lines, we "add" if we have any new ones ONLY..
    set nums      {}
    set lown     -1
    set highn    -1
    set lowl     -1
    set highl     0
    set functions {}
    set last_function {}
    set display_lines {}
    set display_number {}

    # Look at all lines
    foreach line $Lines {
      set num [gdb_tracepoint_exists "$File:$line"]
      if {$num == -1} {
	set New 1
      } else {
	set Exists 1
      }
      
      set function [gdb_get_function "$File:$line"]
      if {"$last_function" != "$function"} {
	lappend functions $function
	set last_function $function
      }

      if {$lown == -1 && $num != -1} {
	set lown $num
      }
      if {$lowl == -1} {
	set lowl $line
      }

      lappend Number $num
      if {$num > $highn} {
	set highn $num
      }
      if {$num != -1 && $num < $lown} {
	set lown $num
      }
      if {$line > $highl} {
	set highl $line
      }
      if {$line < $lowl} {
	set lowl $line
      } 
    }
    
    # Look at all addresses
    foreach addr $Addresses {
      set num [gdb_tracepoint_exists "*$addr"]
      if {$num == -1} {
	set New 1
      } else {
	set Exists 1
      }
      
      set function [gdb_get_function "*$addr"]
      if {"$last_function" != "$function"} {
	lappend functions $function
	set last_function $function
      }

      if {$lown == -1 && $num != -1} {
	set lown $num
      }
      if {$lowl == -1} {
	set lowl $addr
      }

      lappend Number $num
      if {$num > $highn} {
	set highn $num
      }
      if {$num != -1 && $num < $lown} {
	set lown $num
      }
      if {$addr > $highl} {
	set highl $addr
      }
      if {$addr < $lowl} {
	set lowl $addr
      } 
    }

    if {$Lines != {}} {
      if {[llength $Lines] == 1} {
	set Number $lown
	set display_number [concat $Number]
	set display_lines  [concat $Lines]
	set multiline 0
      } else {
	# range of numbers
	set display_number "$lown-$highn"
	set display_lines  "$lowl-$highl"
	set multiline 1
      }
    } elseif {$Addresses != {}} {
      if {[llength $Addresses] == 1} {
	set Number $lown
	set display_number [concat $Number]
	set display_lines  [concat $Addresses]
	set multiline 0
      } else {
	# range of numbers
	set display_number "$lown-$highn"
	set display_lines  "$lowl-$highl"
	set multiline 1
      }
    } elseif {$Number != {}} {
      set New 0
      set multiline 0
      set display_number $Number
    }

    # The three frames of this dialog
    set bbox [frame $f.bbox];		     # for holding OK,CANCEL DELETE buttons
    tixLabelFrame $f.exp -label "Experiment"
    set exp [$f.exp subwidget frame];	     # the "Experiment" frame
    tixLabelFrame $f.act -label "Actions"
    set act [$f.act subwidget frame];	     # the "Actions" frame

    # Setup the button box
    button $bbox.ok     -text OK -command "$this ok"
    button $bbox.cancel -text CANCEL -command "$this cancel"
    set Delete [button $bbox.delete -text DELETE -command "$this delete_tp"]
    pack $bbox.ok $bbox.cancel -side left -padx 10 -expand yes
    pack $bbox.delete -side right -padx 10 -expand yes

    # Setup the "Experiment" frame
    if $New {
      set hit_count   "N/A"
      set thread      "N/A"
      set _TPassCount 0
      if !$Exists {
	$Delete configure -state disabled
      }
    } else {
      if !$multiline {
	set stuff [gdb_get_tracepoint_info $Number]
	# 0=file 1=func 2=line 3=addr 4=disposition 5=passCount 6=stepCount
	# 7=thread 8=hitCount 9=actions
	set enabled [lindex $stuff 4]
	set _TPassCount [lindex $stuff 5]
	set thread      [lindex $stuff 7]
	set hit_count   [lindex $stuff 8]
	set actions     [lindex $stuff 9]
	if {$File == {}} {
	  set File [lindex $stuff 0]
	}
	if {$Lines == {} && $Addresses == {}} {
	  set Addresses [lindex $stuff 3]
	  set display_lines $Addresses
	}
	if {$functions == {}} {
	  set functions [lindex $stuff 1]
	}
      } else {
	# ummm...
	set hit_count "N/A"
	set thread    "N/A"

	# !! Assumptions...
	set stuff [gdb_get_tracepoint_info [lindex $Number 0]]
	set _TPassCount [lindex $stuff 5]
	set actions     [lindex $stuff 9]
      }
    }

    # Number
    label $exp.numlbl -text {Number:}
    label $exp.number -text $display_number

    # File
    label $exp.fillbl -text {File:}
    label $exp.file   -text $File
    # Line
    if {$Lines != {}} {
      label $exp.linlbl -text {Line(s):}
    } else {
      label $exp.linlbl -text {Address(es):}
    }
    label $exp.line   -text $display_lines

    # Function
    if {[llength $functions] > 1} {
      # Do not allow this until we clean up the action dialog...
      tk_messageBox -type ok -icon error -message "Cannot set tracepoint ranges across functions!"
      after idle manage delete $this
    }
    #set functions [join $functions ,]
    label $exp.funlbl -text {Function:}
    label $exp.funct  -text [concat $functions]

    # Hit count
    label $exp.hitlbl -text {Hit Count:}
    label $exp.hit    -text $hit_count

    # Thread
    label $exp.thrlbl -text {Thread:}
    label $exp.thread -text $thread

    # Place these onto the screen
    grid $exp.numlbl -row 0 -column 0 -sticky w -padx 10 -pady 1
    grid $exp.number -row 0 -column 1 -sticky w -padx 10 -pady 1
    grid $exp.funlbl -row 0 -column 2 -sticky w -padx 10 -pady 1
    grid $exp.funct  -row 0 -column 3 -sticky w -padx 10 -pady 1
    grid $exp.hitlbl -row 1 -column 0 -sticky w -padx 10 -pady 1
    grid $exp.hit    -row 1 -column 1 -sticky w -padx 10 -pady 1
    grid $exp.fillbl -row 1 -column 2 -sticky w -padx 10 -pady 1
    grid $exp.file   -row 1 -column 3 -sticky w -padx 10 -pady 1
    grid $exp.thrlbl -row 2 -column 0 -sticky w -padx 10 -pady 1
    grid $exp.thread -row 2 -column 1 -sticky w -padx 10 -pady 1
    grid $exp.linlbl -row 2 -column 2 -sticky w -padx 10 -pady 1
    grid $exp.line   -row 2 -column 3 -sticky w -padx 10 -pady 1

    # Configure columns
    grid columnconfigure $exp 0 -weight 1
    grid columnconfigure $exp 1 -weight 1
    grid columnconfigure $exp 2 -weight 1
    grid columnconfigure $exp 3 -weight 1    

    # The "Actions" Frame
    set pass_frame [frame $act.pass]
    set act_frame  [frame $act.actions]
    set new_frame  [frame $act.new]

    # Pack these frames
    pack $pass_frame $act_frame $new_frame -side top -expand yes -fill both

    # Passes
    label $pass_frame.lbl -text {Number of Passes:}
    entry $pass_frame.ent -textvariable _TPassCount -width 5
    pack $pass_frame.lbl -side left -padx 10 -pady 5
    pack $pass_frame.ent -side right -padx 10 -pady 5

    # Actions
    tixScrolledListBox $act_frame.lb -scrollbar auto
    set ActionLB [$act_frame.lb subwidget listbox]
    label $act_frame.lbl -text {Actions}
    pack $act_frame.lbl -side top
    pack $act_frame.lb -side bottom -fill x -padx 5 -pady 5
    bind $ActionLB <Double-1> "$this edit"

    # New actions
    tixComboBox $new_frame.combo -command "$this set_action_type"
    foreach i {collect while-stepping} {
      $new_frame.combo appendhistory $i
    }
    $new_frame.combo pick 0
    button $new_frame.but -text {Add} -command "$this add_action"
    pack $new_frame.combo $new_frame.but -side left -fill x \
      -padx 5 -pady 5    

    # Pack the main frames
    pack $f.exp $f.act $bbox -side top -padx 5 -pady 2 \
      -expand yes -fill x

    # If we are not new, add all actions
    if !$New {
      add_all_actions $actions
    }
    
    # !! FOR SOME REASON, THE *_FRAMES DO NOT GET MAPPED WHENEVER THE USER
    # WAITS A FEW SECONDS TO PLACE THIS DIALOG ON THE SCREEN. This is here
    # as a workaround so that the action-related widgets don't disappear...
    update idletasks
  }

  method set_action_type {action} {
    set ActionType $action
  }

  method add_action {} {

    if {"$ActionType" == "while-stepping"} {
      if $WhileStepping {
	# We are only allowed on of these...
	tk_messageBox -icon error -type ok -message "A tracepoint may only have one while-stepping action."
	return
      }
      set whilestepping 1
      set step_args "-Steps 1"
    } else {
      set whilestepping 0
      set step_args {}
    }

    #debug "ADDING ACTION FOR $File:[lindex $Lines 0]"
    if {$Lines != {}} {
      set ActionsDlg [eval manage create actiondlg -File $File \
			-Line [lindex $Lines 0] \
			-WhileStepping $whilestepping -Number [lindex $Number 0]\
			-Callback \"$this done\" $step_args]
    } else {
      set ActionsDlg [eval manage create actiondlg -File $File \
			-Address [lindex $Addresses 0] \
			-WhileStepping $whilestepping -Number [lindex $Number 0]\
			-Callback \"$this done\" $step_args]
    }
  }

  method done {status {steps 0} {data {}}} {
    
    # We have just returned from the ActionDlg: must reinstall our grab
#    after idle grab $this

    switch $status {
      cancel {
	# Don't do anything
	set ActionsDlg {}
	return
      }
      add {
	add_action_to_list $steps $data
	set ActionsDlg {}
      }
      delete {
	# do something
	set ActionsDlg {}
      }
      modify {
	# Delete the current selection and insert the new on in its place
	$ActionLB delete $Selection
	add_action_to_list $steps $data $Selection
	set ActionsDlg {}
      }
      default {
	debug "Unknown status from ActionDlg : \"$status\""
      }
    }
  }

  method add_action_to_list {steps data {index {}}} {

    set data [join $data ,]

    if {$steps > 0} {
      if {"$index" == ""} {
	set index "end"
      }
      $ActionLB insert $index "while-stepping ($steps): $data"
      set WhileStepping 1
    } else {
      if {"$index" == ""} {
	set index 0
      }
      $ActionLB insert $index "collect: $data"
    }
  }
  
  # ------------------------------------------------------------------
  # METHOD: cancel - cancel the dialog and do not set the trace
  # ------------------------------------------------------------------
  method cancel {} {
    manage delete $this
  }

  # ------------------------------------------------------------------
  # METHOD: ok - validate the tracepoint and install it
  # ------------------------------------------------------------------
  method ok {} {
    
    # We "dismiss" the dialog here...
    wm withdraw [winfo toplevel $this]

    set actions [get_actions]
    # Check that we are collecting data

    # This is silly, but, hey, it works.
    # Lines is the line number where the tp is 
    # in case of a tp-range it is the set of lines for that range
    if {$Lines != {}} {
      for {set i 0} {$i < [llength $Number]} {incr i} {
	set number [lindex $Number $i]
	set line   [lindex $Lines $i]

	if {$number == -1} {
	  #debug "Adding new tracepoint at $File:$line $_TPassCount $actions"
	  set err [catch {gdb_add_tracepoint $File:$line $_TPassCount $actions} errTxt]
	} else {
	  if {$New && $Exists} {
	    set result [tk_messageBox -icon error -type yesno \
			  -message "Overwrite actions for tracepoint \#$number at $File:$line?" \
			  -title "Query"]
	    if {"$result" == "no"} {
	      continue
	    }
	  }
        if {$New == 0 && $Exists == 1} {
          set tpnum [gdb_tracepoint_exists "$File:$line"]
          if {$tpnum == -1} {
             tk_messageBox -type ok -icon error -message "Tracepoint was deleted"
             manage delete $this
             return
           }
        }

	  #debug "Editing tracepoint \#$Number: $_TPassCount $actions"
	  set err [catch {gdb_edit_tracepoint $number $_TPassCount $actions} errTxt]
	}

	if $err {
	  if {$number == -1} {
	    set str "adding new tracepoint at $File:$line"
	  } else {
	    set str "editing tracepoint $number at $File:$line"
	  }
	  tk_messageBox -type ok -icon error -message "Error $str: $errTxt"
	}
      }
    } else {
      # Async
      for {set i 0} {$i < [llength $Number]} {incr i} {
	set number [lindex $Number $i]
	set addr   [lindex $Addresses $i]
	if {$number == -1} {
	  #debug "Adding new tracepoint at $addr in $File; $_TPassCount $actions"
	  set err [catch {gdb_add_tracepoint {} $_TPassCount $actions $addr} errTxt]
	} else {
	  if {$New && $Exists} {
	    set result [tk_messageBox -icon error -type yesno \
			  -message "Overwrite actions for tracepoint \#$number at $File:$line?" \
			  -title "Query"]
	    if {"$result" == "no"} {
	      continue
	    }
	  }
        if {$New == 0 && $Exists == 1} {
          set num [gdb_tracepoint_exists "$File:$Line"]
          if {$num == -1} {
             tk_messageBox -type ok -icon error -message "Tracepoint was deleted"
             manage delete $this
             return
          }
       }
	  #debug "Editing tracepoint \#$Number: $_TPassCount $actions"
	  set err [catch {gdb_edit_tracepoint $number $_TPassCount $actions} errTxt]
	}

	if $err {
	  if {$number == -1} {
	    set str "adding new tracepoint at $addr in $File"
	  } else {
	    set str "editing tracepoint $number at $addr in $File"
	  }
	  tk_messageBox -type ok -icon error -message "Error $str: $errTxt"
	}
      }
    }
    
    manage delete $this
  }

  method cmd {line} {
    $line
  }

  method delete_tp {} {
    debug "deleting tracepoint $Number"
    set err [catch {gdb_cmd "delete tracepoints $Number"} errTxt]
    debug "done deleting tracepoint $Number"
    manage delete $this
  }

  method get_data {action} {

    set data {}
    foreach a $action {
      set datum [string trim $a \ \r\n\t,]
      if {"$datum" == "collect" || "$datum" == ""} {
	continue
      }

      lappend data $datum
    }
      
    return $data
  }
  
  method add_all_actions {actions} {
    
    set length [llength $actions]
    for {set i 0} {$i < $length} {incr i} {
      set action [lindex $actions $i]

      if [regexp "collect" $action] {
	set steps 0
	set data [get_data $action]
      } elseif [regexp "while-stepping" $action] {
	scan $action "while-stepping %d" steps
	incr i
	set action [lindex $actions $i]
	set data [get_data $action]
      } elseif [regexp "end" $action] {
	continue
      }

      # Now have an action: data and steps
      add_action_to_list $steps $data
    }
  }

  method get_actions {} {
    
    set actions {}
    set list [$ActionLB get 0 end]
    foreach action $list {
      if [regexp "collect" $action] {
	scan $action "collect: %s" data
	set steps 0
	set whilestepping 0
      } elseif [regexp "while-stepping" $action] {
	scan $action "while-stepping (%d): %s" steps data
	set whilestepping 1
      } else {
	debug "unknown action: $action"
	continue
      }

      lappend actions [list $steps $data]
    }

    return $actions
  }

  method edit {} {
    
    set Selection [$ActionLB curselection]
    set action [$ActionLB get $Selection]
    if [regexp "collect" $action] {
      scan $action "collect: %s" data
      set steps 0
      set whilestepping 0
    } elseif [regexp "while-stepping" $action] {
      scan $action "while-stepping (%d): %s" steps data
      set whilestepping 1
    } else {
      debug "unknown action: $action"
      return
    }
    
    set data [split $data ,] 
    set len [llength $data]
    set real_data {}
    set special 0
    for {set i 0} {$i < $len} {incr i} {
      set a [lindex $data $i]
      if {[string range $a 0 1] == "\$("} {
	set special 1
	set b $a
      } elseif {$special} {
	lappend b $a
	if {[string index $a [expr {[string length $a]-1}]] == ")"} {
	  lappend real_data [join $b ,]
	  set special 0
	}
      } else {
	lappend real_data $a
      }
    }
    
    # !! lindex $Lines 0 -- better way?
    if {$Lines != {}} {
      manage create actiondlg -File $File -Line [lindex $Lines 0] \
	-WhileStepping $whilestepping -Number [lindex $Number 0] \
	-Callback "$this done" -Data $real_data -Steps $steps
    } else {
      manage create actiondlg -File $File -Address [lindex $Addresses 0] \
	-WhileStepping $whilestepping -Number [lindex $Number 0] \
	-Callback "$this done" -Data $real_data -Steps $steps
    }
  }

  method get_selection {} {
    
    set action [$ActionLB curselection]
    return [$ActionLB get $action]
  }

  # ------------------------------------------------------------------
  #   METHOD:  title - Title the trace dialog.
  #
  #        This is needed to title the window after the dialog has
  #        been created. The window manager actually sets our title
  #        after we've been created, so we need to do this in an
  #        "after idle".
  # ------------------------------------------------------------------
  method title {} {
    if $New {
      set display_number "N/A"
      wm title [winfo toplevel $this] "Add Tracepoint"
    } else {
      wm title [winfo toplevel $this] "Edit Tracepoint"
    }
  }

  # PUBLIC DATA
  public File {}
  public Lines {}
  public Addresses {}
  public Number {}

  # PROTECTED DATA
  protected Delete
  protected _TPassCount
  protected ActionType {}
  protected ActionLB
  protected Actions
  protected WhileStepping 0
  protected Selection {}
  protected New 0;			# set whenever there is a new tp to add
  protected Exists 0;			# set whenever a tracepoint in the range exists
  protected Dismissed 0;		# has this dialog been dismissed already?
  protected ActionsDlg {}
}

proc gdb_add_tracepoint {where passes actions {addr {}}} {
  #debug "gdb_add_tracepoint $where $passes $actions $addr"
  
  # Install the tracepoint
  if {$where == "" && $addr != ""} {
    set where "*$addr"
  }

  #debug "trace $where"
  set err [catch {gdb_cmd "trace $where"} errTxt]

  if $err {
    tk_messageBox -type ok -icon error -message $errTxt
    return
  }

  # Get the number for this tracepoint
  set number [gdb_tracepoint_exists $where]

  # If there is a pass count, add that, too
  set err [catch {gdb_cmd "passcount $passes $number"} errTxt]

  if $err {
    tk_messageBox -type ok -icon error -message $errTxt
    return
  }

  set real_actions {}
  foreach action $actions {
    set steps [lindex $action 0]
    set data  [lindex $action 1]

    if $steps {
      lappend real_actions "while-stepping $steps"
      lappend real_actions "collect $data"
      lappend real_actions "end"
    } else {
      lappend real_actions "collect $data"
    }
  }

  if {[llength $real_actions] > 0} {
    lappend real_actions "end"
  }

  set err [catch {gdb_actions $number $real_actions} errTxt]
   if $err {
    set errTxt "$errTxt Tracepoint will be installed with no actions"
    tk_messageBox -type ok -icon error -message $errTxt
    return
   }
}

proc gdb_edit_tracepoint {number passes actions} {
  #debug "gdb_edit_tracepoint $number $passes $actions"

  # If there is a pass count, add that, too
  set err [catch {gdb_cmd "passcount $passes $number"} errTxt]
    
  if $err {
    tk_messageBox -type ok -icon error -message $errTxt
    return
  }
  
  set real_actions {}
  foreach action $actions {
    set steps [lindex $action 0]
    set data  [lindex $action 1]

    if $steps {
      lappend real_actions "while-stepping $steps"
      lappend real_actions "collect $data"
      lappend real_actions "end"
    } else {
      lappend real_actions "collect $data"
    }
  }
  
  if {[llength $real_actions] > 0} {
    lappend real_actions "end"
  }
  
  gdb_actions $number $real_actions
}

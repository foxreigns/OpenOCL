classdef Simulator < handle
  
  properties
    integrator
    model
  end
  
  methods (Static)
    function options = getOptions()
      options = struct;
    end
  end
  
  methods
    
    function self = Simulator(model,options)
      self.integrator = CasadiIntegrator(model);
      self.model = model;
    end
    
    function [statesVec,algVarsVec,controlsVec] = simulate(self,initialState,times,parameters)
      
      N = length(times)-1;
      statesVec = Var('states');
      statesVec.addRepeated({self.model.state},N+1);
      algVarsVec = Var('algVars');
      algVarsVec.addRepeated({self.model.algState},N);
      controlsVec = Var('controls');
      controlsVec.addRepeated({self.model.controls},N);
      
      state = getConsistentIntitialCondition(self,initialState,parameters);
      algState = self.model.algState;
      algState.set(0);
 
      statesVec.get('state',1).set(state.flat);
      
      for k=1:N
        timestep = times(k+1)-times(k);
        controls = self.model.callIterationCallback(state,algState,parameters);
        [stateVal,algStateVal] = self.integrator.evaluate(state.flat,algState.flat,controls.flat,timestep,parameters.flat);
        stateVal = full(stateVal);
        algStateVal = full(algStateVal);
        
        statesVec.get('state',k+1).set(stateVal);
        algVarsVec.get('algState',k).set(algStateVal);
        controlsVec.get('controls',k).set(controls.flat);
        
        state.set(stateVal);
        algState.set(algStateVal);
      end  
    end
    
    function state = getState(self)
      state = self.model.state.copy;
      state.set(0);
    end
    
    function state = getConsistentIntitialCondition(self,state,parameters)
      
      % check initial condition
      ic = self.model.getInitialCondition(state,parameters);
      
      if ~all(ic==0)
        warning('Initial state is not consistent, trying to find a consistent initial condition...');
        stateSym  = state.copy;
        CasadiLib.setSX(stateSym);
        ic = self.model.getInitialCondition(stateSym,parameters);
        
        nlp    = struct('x', stateSym.flat, 'f', 0, 'g', ic);
        solver = casadi.nlpsol('solver', 'ipopt', nlp);
        sol    = solver('x0', state.flat, 'lbx', -inf, 'ubx', inf,'lbg', 0, 'ubg', 0);
        
        consistentState  = full(sol.x);
        state.set(consistentState);
      end
      
    end
    
  end
  
end
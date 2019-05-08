classdef OclSystem < handle

  properties
    varsfh
    daefh
    icfh
    cbfh
    cbsetupfh
    
    thisInitialConditions
    
    states
    algvars
    controls
    parameters
    stateBounds
    algvarBounds
    controlBounds
    parameterBounds
    
    statesOrder
  end

  methods

    function self = OclSystem(varargin)
      % OclSystem()
      % OclSystem(fhVarSetup,fhEquationSetup)
      % OclSystem(fhVarSetup,fhEquationSetup,fhInitialCondition)

      emptyfh = @(varargin)[];

      p = inputParser;
      p.addOptional('varsfunOpt', [], @oclIsFunHandleOrEmpty);
      p.addOptional('eqfunOpt', [], @oclIsFunHandleOrEmpty);
      p.addOptional('icfunOpt', [], @oclIsFunHandleOrEmpty);

      p.addParameter('varsfun', emptyfh, @oclIsFunHandle);
      p.addParameter('eqfun', emptyfh, @oclIsFunHandle);
      p.addParameter('icfun', emptyfh, @oclIsFunHandle);
      p.addParameter('cbfun', emptyfh, @oclIsFunHandle);
      p.addParameter('cbsetupfun', emptyfh, @oclIsFunHandle);
      p.parse(varargin{:});

      varsfun = p.Results.varsfunOpt;
      if isempty(varsfun)
        varsfun = p.Results.varsfun;
      end

      daefun = p.Results.eqfunOpt;
      if isempty(daefun)
        daefun = p.Results.eqfun;
      end

      icfun = p.Results.icfunOpt;
      if isempty(icfun)
        icfun = p.Results.icfun;
      end

      self.varsfh = varsfun;
      self.daefh = daefun;
      self.icfh = icfun;

      self.cbfh = p.Results.cbfun;
      self.cbsetupfh = p.Results.cbsetupfun;
      
      svh = OclSysvarsHandler;
      self.varsfh(svh);
      
      self.states = svh.states;
      self.algvars = svh.algvars;
      self.controls = svh.controls;
      self.parameters = svh.parameters;
      self.stateBounds = svh.stateBounds;
      self.algvarBounds = svh.algvarBounds;
      self.controlBounds = svh.controlBounds;
      self.parameterBounds = svh.parameterBounds;
      
      self.statesOrder = svh.statesOrder;

    end

    function r = nx(self)
      r = prod(self.states.size());
    end

    function r = nz(self)
      r = prod(self.algvars.size());
    end

    function r = nu(self)
      r = prod(self.controls.size());
    end

    function r = np(self)
      r = prod(self.parameters.size());
    end
    
    function simulationCallbackSetup(~)
      % simulationCallbackSetup()
    end

    function simulationCallback(varargin)
      % simulationCallback(states,algVars,controls,timeBegin,timesEnd,parameters)
    end

    function [ode,alg] = daefun(self,x,z,u,p)
      % evaluate the system equations for the assigned variables

      x = Variable.create(self.states,x);
      z = Variable.create(self.algvars,z);
      u = Variable.create(self.controls,u);
      p = Variable.create(self.parameters,p);

      daehandler = OclDaeHandler();
      self.daefh(daehandler,x,z,u,p);

      ode = daehandler.getOde(self.nx, self.statesOrder);
      alg = daehandler.getAlg(self.nz);
    end

    function ic = icfun(self,x,p)
      icHandler = OclConstraint();
      x = Variable.create(self.states,x);
      p = Variable.create(self.parameters,p);
      self.icfh(icHandler,x,p)
      ic = icHandler.values;
      assert(all(icHandler.lowerBounds==0) && all(icHandler.upperBounds==0),...
          'In initial condition are only equality constraints allowed.');
    end

    function solutionCallback(self,times,solution)
      sN = size(solution.states);
      N = sN(3);
      
      t = times.states;

      for k=1:N-1
        x = solution.states(:,:,k+1);
        z = solution.integrator(:,:,k).algvars;
        u =  solution.controls(:,:,k);
        p = solution.parameters(:,:,k);
        self.cbfh(x,z,u,t(:,:,k),t(:,:,k+1),p);
      end
    end

    function callSimulationCallbackSetup(self)
      self.cbsetupfh();
    end

    function u = callSimulationCallback(self,states,algVars,controls,timesBegin,timesEnd,parameters)
      x = Variable.create(self.states,states);
      z = Variable.create(self.algvars,algVars);
      u = Variable.create(self.controls,controls);
      p = Variable.create(self.parameters,parameters);

      t0 = Variable.Matrix(timesBegin);
      t1 = Variable.Matrix(timesEnd);

      self.cbfh(x,z,u,t0,t1,p);
      u = Variable.getValueAsColumn(u);
    end

  end
end
